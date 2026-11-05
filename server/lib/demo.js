// Self-explaining demo videos (D-164): a replay filmed slowly enough to read, with a timeline of what each
// step did and where its element was, plus plain-words notes in English and Bahasa Indonesia that the Mac
// app burns in as cards, subtitles and pointers. The notes are written once per case (Claude) and kept in
// the macro (`demo`), so replays, bundles and re-renders reuse them for free. Nothing here changes the test.
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { mocksDir } from "./mock-pack.js";
import { uiTestRoot } from "./macro-v2.js";

export const LANGUAGES = ["en", "id"];
const CHECK_KINDS = new Set(["assert", "waitFor", "waitForGone", "assertRequested"]);
const ACTION_KINDS = new Set(["tap", "type", "typeSecret", "swipe", "scrollTo", "scrollToTop", "openDeeplink"]);
/** Long enough to read a two-line subtitle and see the pointer before the next step moves the screen. */
export const DEFAULT_HOLD_MS = { action: 1500, check: 2500 };

const isText = (value) => typeof value === "string" && value.trim().length > 0;
const bilingual = (value) => (value && LANGUAGES.every((lang) => isText(value[lang])) ? Object.fromEntries(LANGUAGES.map((lang) => [lang, value[lang].trim()])) : null);

export const isCheck = (step) => CHECK_KINDS.has(step?.do);
export const isAction = (step) => ACTION_KINDS.has(step?.do);

// --- Notes ---------------------------------------------------------------------------------------

export function demoNotesPrompt({ testCase, macroName, rows, mocks, techNotes }) {
	const caseText = testCase ? JSON.stringify(testCase, null, 1).slice(0, 4000) : "(no test case text — use the steps)";
	return [
		"You write the subtitles for a short demo video of one automated app test, for viewers with no project knowledge:",
		"managers, new developers, designers. They must understand what is tested and why from the video alone.",
		"",
		"Rules:",
		"- Plain words. Never say API, endpoint, mock, macro, identifier, element, assert, JSON, flag or field names.",
		"  Say what a person sees: 'the page', 'the tab bar', 'the iPhone tab', 'the server sends…'.",
		"- Use the words visible on screen when you know them. Short: a step note ≤ 14 words, a check note ≤ 18 words.",
		"- A check note says what should be seen and why it matters ('The tab bar shrinks — proof the page scrolled').",
		"- Write every text in English (en) and Bahasa Indonesia (id). Natural Bahasa, not word-for-word.",
		"- Only notes for the step ids listed below; skip steps a viewer doesn't need (screenshots, alerts, routines)",
		"  by leaving them out.",
		"",
		`Test: ${macroName}`,
		`Test case: ${caseText}`,
		"",
		"Steps (id · what the robot does · technical note):",
		...rows.map((row) => `- ${row.id} · ${row.text}${row.note ? ` · ${row.note}` : ""}`),
		"",
		"Server answers this test sets up (endpoint → variant name · technical note):",
		...(mocks.length ? mocks.map((mock) => `- ${mock.endpoint} → ${mock.variant}${mock.note ? ` · ${mock.note}` : ""}`) : ["- none"]),
		...(techNotes ? ["", `Feature notes: ${techNotes.slice(0, 3000)}`] : []),
		"",
		"Answer with JSON only, no prose:",
		'{"title":{"en":"","id":""},"checks":{"en":"what this test checks, one sentence","id":""},',
		'"why":{"en":"why it matters to a shopper, one sentence","id":""},',
		'"setup":{"en":"what the server is made to send, plain words","id":""},',
		'"steps":{"<step id>":{"en":"","id":""}},',
		'"mocks":{"<endpoint>":{"<variant>":{"en":"plain words for this server answer","id":""}}}}',
	].join("\n");
}

/**
 * Validates Claude's answer; a step note for an unknown step id is dropped rather than trusted. Endpoint keys
 * are matched back to the test's own (`/a` → `GET /a`) — the answer tends to drop the method.
 */
export function parseDemoNotes(text, stepIds, endpoints = []) {
	const match = String(text ?? "").match(/\{[\s\S]*\}/);
	if (!match) throw new Error("the notes answer had no JSON");
	const raw = JSON.parse(match[0]);
	const notes = {};
	for (const key of ["title", "checks", "why", "setup"]) {
		const value = bilingual(raw[key]);
		if (!value && key !== "setup") throw new Error(`the notes miss "${key}" in English or Bahasa`);
		if (value) notes[key] = value;
	}
	notes.steps = {};
	for (const [id, value] of Object.entries(raw.steps ?? {})) {
		const note = bilingual(value);
		if (note && stepIds.includes(id)) notes.steps[id] = note;
	}
	const mocks = {};
	for (const [written, variants] of Object.entries(raw.mocks ?? {})) {
		const endpoint = endpoints.find((known) => known === written) ?? endpoints.find((known) => known.endsWith(` ${written}`) || known.endsWith(written)) ?? written;
		for (const [variant, value] of Object.entries(variants ?? {})) {
			const note = bilingual(value);
			if (note) mocks[endpoint] = { ...(mocks[endpoint] ?? {}), [variant]: note };
		}
	}
	return { notes, mocks };
}

// --- Plain words for mock answers, shared by every case and carried by bundles ---------------------

export const mockNotesPath = (root = uiTestRoot()) => join(mocksDir(root), "notes.json");

export async function loadMockNotes(root = uiTestRoot()) {
	try {
		return JSON.parse(await readFile(mockNotesPath(root), "utf8"));
	} catch {
		return {};
	}
}

/** Adds notes for answers that have none; `overwrite` replaces existing ones too. Returns how many were written. */
export async function mergeMockNotes(additions, { root = uiTestRoot(), overwrite = false } = {}) {
	const current = await loadMockNotes(root);
	let written = 0;
	for (const [endpoint, variants] of Object.entries(additions ?? {})) {
		for (const [variant, note] of Object.entries(variants ?? {})) {
			if (current[endpoint]?.[variant] && !overwrite) continue;
			current[endpoint] = { ...(current[endpoint] ?? {}), [variant]: note };
			written += 1;
		}
	}
	if (written) await writeJson(mockNotesPath(root), current);
	return written;
}

async function writeJson(path, value) {
	await mkdir(dirname(path), { recursive: true });
	const temporary = `${path}.tmp-${process.pid}`;
	await writeFile(temporary, `${JSON.stringify(value, null, 2)}\n`);
	await rename(temporary, path);
}

/** Writes `demo` into the macro file where it lives, keeping everything else as it is. */
export async function saveMacroNotes(macroPath, notes, { root = uiTestRoot() } = {}) {
	const path = join(root, macroPath);
	const macro = JSON.parse(await readFile(path, "utf8"));
	macro.demo = { ...notes, writtenAt: new Date().toISOString() };
	await writeJson(path, macro);
	return macro;
}

// --- Recording the timeline ----------------------------------------------------------------------

/**
 * Hooks for a demo replay: frames where the viewer should look, and a pause after each so the subtitle
 * can be read. Times are milliseconds since `begin()` — the moment the screen recording started.
 * Actions are framed before they run (where the finger goes); checks after (what should be seen), except
 * a check that something disappears, framed before it goes.
 */
/** `onFocus` (D-165 live overlay) hears where to look as it happens; `notedStepIds` are top-level steps with a note,
 *  held long enough to read even when they have no element to point at. */
export function createDemoRecorder({ fetchFrame, screen, now = Date.now, sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)), holdMs = DEFAULT_HOLD_MS, onFocus = () => {}, notedStepIds = new Set() }) {
	let startedAt = null;
	let current = null;
	let currentStep = null;
	const events = [];
	const at = () => (startedAt === null ? 0 : now() - startedAt);
	const frame = async (step) => (step.identifier ? fetchFrame(step.identifier).catch(() => null) : null);
	const focus = (step, style, stepFrame) => onFocus({ stepId: step.id ?? null, from: step.from ?? null, do: step.do, text: step.text ?? null, style, frame: stepFrame ?? null });
	return {
		events,
		begin() {
			startedAt = now();
		},
		async onStepStart(step) {
			currentStep = step;
			current = { id: step.id, do: step.do, text: step.text ?? null, from: step.from ?? null, startMs: at(), frame: null };
			// A shared setup routine (Open Home, log in) is plumbing: no pointer, no reading pause.
			if (step.from) {
				focus(step, "step", null);
				return;
			}
			if (isAction(step) || step.do === "waitForGone") {
				current.frame = await frame(step);
				current.startMs = at();
			}
			focus(step, isAction(step) ? "action" : isCheck(step) ? "checking" : "step", current.frame);
			const isNoted = !step.from && notedStepIds.has(step.id);
			if ((current.frame && isAction(step)) || (isNoted && !isCheck(step))) await sleep(holdMs.action);
		},
		async onStep(row) {
			const step = currentStep;
			if (!current || !step) return;
			const event = { ...current, text: row.text ?? current.text, endMs: at(), ok: Boolean(row.ok || row.skipped), skipped: Boolean(row.skipped) };
			const isShown = !step.from && !row.skipped;
			if (isCheck(step) && step.do !== "waitForGone" && isShown) event.frame = (await frame(step)) ?? event.frame;
			events.push(event);
			current = null;
			if (isCheck(step) && isShown) {
				focus({ ...step, text: event.text }, event.ok ? "passed" : "failed", event.frame);
				await sleep(holdMs.check);
				event.holdUntilMs = at();
			}
		},
		timeline({ caseId, macro, notes, mockNotes, mocks, verdict }) {
			return { schema: 1, caseId, macroId: macro.id, macroName: macro.name, recordedAt: new Date(now()).toISOString(), screen, verdict, languages: LANGUAGES, notes, mocks: mocks.map((mock) => ({ ...mock, note: mockNotes[mock.endpoint]?.[mock.variant] ?? null })), events };
		},
	};
}
