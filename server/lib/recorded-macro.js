// D-171: Scan › Record a macro. A person taps through the app; the Mac app sends each gesture with the element under
// the pointer and an identifier that appeared on the screen it led to. This turns them into a v2 macro: taps by
// accessibility identifier (label only as a fallback), a wait for the next screen, a screenshot per new screen.
import { access } from "node:fs/promises";
import { join } from "node:path";
import { macroSlug, newId, targetOf } from "./macro-v2.js";

const SWIPES = { swipeUp: "up", swipeDown: "down", swipeLeft: "left", swipeRight: "right" };
const SCREEN_WAIT_S = 15;
/** D-194: buttons of system alerts (permissions, open-in-app, save password); a tap on one replays as an alert answer. */
const SYSTEM_ALERT_BUTTONS = new Set(["Allow", "Allow Once", "Allow While Using App", "Don’t Allow", "Don't Allow", "Ask App Not to Track", "Open", "Not Now", "Save Password", "Never for This Website"]);
const ALERT_WAIT_S = 3;

/** How a recorded gesture will be found on replay: "identifier", "label" (breaks when copy or language changes) or "none". */
export function anchorQuality(gesture) {
	if (clean(gesture?.identifier)) return "identifier";
	if (containerOf(gesture)) return "container";
	if (isSystemAlertTap(gesture)) return "alert";
	if (clean(gesture?.label)) return "label";
	return "none";
}

/** D-194: the tapped element's container and position when it has no identifier of its own. */
function containerOf(gesture) {
	const container = clean(gesture?.containerIdentifier);
	const type = clean(gesture?.elementType);
	return container && type && Number.isInteger(gesture?.index) ? { container, type, index: gesture.index } : null;
}

const isSystemAlertTap = (gesture) => gesture?.gesture === "tap" && !clean(gesture?.identifier) && SYSTEM_ALERT_BUTTONS.has(clean(gesture?.label));

/** Steps that need a developer: no accessibility identifier on what was tapped. Swipes need none. */
export function missingIdentifierWarnings(gestures) {
	return (gestures ?? []).flatMap((gesture, index) => {
		if (gesture?.gesture !== "tap") return [];
		const quality = anchorQuality(gesture);
		if (["identifier", "container", "alert"].includes(quality)) return [];
		const where = clean(gesture.screenName) ? ` on ${gesture.screenName}` : "";
		return [quality === "label"
			? { step: index + 1, quality, text: `Step ${index + 1}: “${clean(gesture.label)}”${where} has no accessibility ID — replay finds it by its text, which breaks when the copy or language changes.` }
			: { step: index + 1, quality, text: `Step ${index + 1}: the element tapped${where} has no accessibility ID and no label — replay can't find it, so this step asks a person to tap.` }];
	});
}

/**
 * Builds the macro and the registry entries it needs. Reuses an element already in the registry for the same
 * identifier (or label) so a later rename is repaired once. Returns `{macro, registry, warnings}`; nothing is written.
 */
export function buildRecordedMacro({ name, caseIds = [], gestures, startFresh = true, now = new Date() }, registry) {
	const elements = { ...(registry?.elements ?? {}) };
	const created = [];
	const element = (locator, { alias, screen, quality }) => {
		const existing = Object.entries(elements).find(([, entry]) => sameLocator(entry, locator));
		if (existing) return existing[0];
		const id = newId("el");
		elements[id] = { alias, ...(screen ? { screen } : {}), quality, locator, createdAt: now.toISOString(), recorded: true };
		created.push(id);
		return id;
	};
	const steps = [];
	const step = (fields) => steps.push({ id: newId("st"), ...fields });
	if (startFresh) step({ do: "relaunch", note: "Recorded from a freshly launched app" });
	(gestures ?? []).forEach((gesture, index) => {
		const label = clean(gesture.label);
		const identifier = clean(gesture.identifier);
		const screen = clean(gesture.screenName) || undefined;
		const said = describe(gesture);
		if (SWIPES[gesture.gesture]) {
			step({ do: "swipe", direction: SWIPES[gesture.gesture], note: `Recorded: ${said}` });
		} else if (identifier) {
			const el = element({ chain: [{ identifier }] }, { alias: label || identifier, screen, quality: "identifier" });
			step({ do: "tap", el, note: `Recorded: ${said}` });
		} else if (isSystemAlertTap(gesture)) {
			step({ do: "alertTap", button: label, optional: true, timeout: ALERT_WAIT_S, note: `Recorded: answered the system alert with “${label}”` });
		} else if (containerOf(gesture)) {
			const { container, type, index: position } = containerOf(gesture);
			const locator = { chain: [{ identifier: container }, { type, index: position }], ...(label ? { fallbacks: [{ label, match: "EQUALS" }] } : {}) };
			const el = element(locator, { alias: label || `${type} ${position + 1} in ${container}`, screen, quality: "container" });
			step({ do: "tap", el, note: `Recorded: ${said} — no accessibility ID, found as ${type} ${position + 1} inside ${container}` });
		} else if (label) {
			const el = element({ fallbacks: [{ label, match: "EQUALS" }] }, { alias: label, screen, quality: "label" });
			step({ do: "tap", el, note: `Recorded: ${said} — no accessibility ID, found by its text` });
		} else {
			step({ do: "manual", title: `Step ${index + 1}: tap by hand`, say: `Tap what you tapped while recording${screen ? ` on ${screen}` : ""} — it has no accessibility ID or label, so replay can't find it.` });
		}
		const anchor = clean(gesture.anchorIdentifier);
		if (anchor) {
			const next = clean(gesture.nextScreenName) || undefined;
			const alias = next ? (/screen$/i.test(next) ? next : `${next} screen`) : anchor;
			const el = element({ chain: [{ identifier: anchor }] }, { alias, screen: next, quality: "identifier" });
			step({ do: "waitFor", el, timeout: SCREEN_WAIT_S, note: next ? `${next} is showing` : undefined });
			step({ do: "screenshot", name: `${macroSlug(name)}-${String(index + 1).padStart(2, "0")}-${macroSlug(next ?? anchor)}` });
		}
	});
	const ids = [...new Set(caseIds.map((id) => String(id).trim()).filter(Boolean))];
	const macro = {
		schemaVersion: 2,
		id: newId("mc"),
		name,
		kind: "flow",
		...(ids.length ? { links: { testCases: ids } } : {}),
		createdAt: now.toISOString(),
		recordedBy: "scan",
		steps: steps.map((entry) => Object.fromEntries(Object.entries(entry).filter(([, value]) => value !== undefined))),
	};
	return { macro, registry: { ...registry, elements }, createdElements: created, warnings: missingIdentifierWarnings(gestures) };
}

/** A free file name next to the others: `name.json`, else `name-2.json`, … — never overwrites another macro. */
export async function freeMacroName(name, folder) {
	const exists = async (candidate) => access(join(folder, `${macroSlug(candidate)}.json`)).then(() => true, () => false);
	if (!(await exists(name))) return name;
	for (let suffix = 2; suffix < 100; suffix += 1) if (!(await exists(`${name} ${suffix}`))) return `${name} ${suffix}`;
	return `${name} ${Date.now()}`;
}

function sameLocator(entry, locator) {
	const target = targetOf(entry);
	if (!target) return false;
	if (locator.chain?.length > 1) {
		const [container, leaf] = locator.chain;
		return target.within === container.identifier && target.elementType === leaf.type && target.index === leaf.index;
	}
	if (locator.chain) return target.by === "identifier" && !target.within && target.identifier === locator.chain[0].identifier;
	return target.by === "label" && target.labels.some((fallback) => fallback.label === locator.fallbacks[0].label);
}

function describe(gesture) {
	if (SWIPES[gesture.gesture]) return `swipe ${SWIPES[gesture.gesture]}`;
	const name = clean(gesture.label) || clean(gesture.identifier);
	return name ? `tap “${name}”` : "tap (unnamed element)";
}

function clean(value) {
	return typeof value === "string" ? value.trim() : "";
}

/** One row of Scan's saved-macros list (D-174): what was recorded, and how much of it replay finds by ID. */
export function recordedMacroSummary(macro, root) {
	const steps = macro.steps ?? [];
	const gestures = steps.filter((step) => ["tap", "swipe", "manual"].includes(step.do));
	const byText = steps.filter((step) => step.do === "tap" && /no accessibility ID, found by its text/.test(step.note ?? "")).length;
	const manual = steps.filter((step) => step.do === "manual").length;
	return {
		id: macro.id,
		name: macro.name,
		createdAt: macro.createdAt ?? null,
		testCases: [...new Set([macro.links?.testCase, ...(macro.links?.testCases ?? [])].filter(Boolean).map(String))],
		path: macro.path ? join(root, macro.path) : null,
		gestureCount: gestures.length,
		foundByText: byText,
		needsPerson: manual,
		startsFresh: steps[0]?.do === "relaunch",
	};
}

/** Scan-recorded macros, newest first. */
export const recordedMacros = (macros, root) => macros
	.filter((macro) => macro.recordedBy === "scan")
	.map((macro) => recordedMacroSummary(macro, root))
	.sort((first, second) => Date.parse(second.createdAt ?? 0) - Date.parse(first.createdAt ?? 0));
