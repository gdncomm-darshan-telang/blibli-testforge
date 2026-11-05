// D-128 (phase B of docs/networklens-console.md): what the Mac Network console edits — rules and their variants as
// plain fields, variant edits, time-shift, scenarios, and the guardrails against leftover mocks. Pure: works on
// NetworkLens rules (the `session.json` / live-state shape) and returns new values; the server writes them.
import { newID } from "./variants.js";
import { sameRule, toSnapshotDate } from "./session.js";

const JSON_HEADERS = { "Content-Type": "application/json" };
const MIN_EPOCH_MS = Date.UTC(2015, 0, 1);
const MAX_EPOCH_MS = Date.UTC(2045, 0, 1);
export const FAILURE_KINDS = {
	offline: { errorCode: -1009, label: "offline" },
	timedOut: { errorCode: -1001, label: "timed out" },
	connectionLost: { errorCode: -1005, label: "connection lost" },
};

const fail400 = (message) => Object.assign(new Error(message), { status: 400 });

/** One variant as the editor shows it. Only single-step variants are editable here; scripted ones say so. */
export function variantView(variant) {
	const steps = variant.steps ?? [];
	const first = steps[0] ?? {};
	const base = { id: variant.id, name: variant.name, stepCount: steps.length, isEditable: steps.length === 1 };
	if (first.respond) {
		const { statusCode = 200, headers = {}, delay = 0, body } = first.respond._0 ?? {};
		return { ...base, kind: "respond", statusCode, headers, delay, body: bodyText(body) };
	}
	if (first.fail) {
		const { errorCode, label, delay = 0 } = first.fail._0 ?? {};
		const failure = Object.entries(FAILURE_KINDS).find(([, entry]) => entry.errorCode === errorCode)?.[0] ?? null;
		return { ...base, kind: "fail", failure, failureLabel: label ?? null, delay };
	}
	if (first.hang) return { ...base, kind: "hang", delay: 0 };
	return { ...base, kind: "unknown", isEditable: false };
}

export function ruleView(rule) {
	return {
		id: rule.id,
		endpoint: rule.endpointKey,
		isEnabled: rule.isEnabled !== false,
		activeVariantId: rule.activeVariantID ?? null,
		variants: (rule.variants ?? []).map(variantView),
	};
}

/**
 * The rule with one variant rewritten from editor fields: `{ name?, kind, statusCode, headers, delay, body, failure }`.
 * `kind` is respond, fail or hang. A respond body that claims JSON must parse — a typo would serve garbage silently.
 */
export function editedRule(rule, variantId, fields) {
	const index = (rule.variants ?? []).findIndex((entry) => entry.id === variantId);
	if (index < 0) throw Object.assign(new Error("no such variant on this rule"), { status: 404 });
	const current = rule.variants[index];
	if ((current.steps ?? []).length > 1) throw Object.assign(new Error(`“${current.name}” answers in ${current.steps.length} steps; edit it in NetworkLens`), { status: 422 });
	const name = String(fields.name ?? current.name).trim();
	if (!name) throw fail400("a variant needs a name");
	if (rule.variants.some((entry, other) => other !== index && entry.name === name)) throw fail400(`this rule already has a variant “${name}”`);
	const next = structuredClone(rule);
	next.variants[index] = { ...current, name, steps: [stepFrom(fields)] };
	return next;
}

/** A copy of `fromVariantId` under `name`, so an edit never has to destroy the captured original. */
export function withCopiedVariant(rule, fromVariantId, name) {
	const source = (rule.variants ?? []).find((entry) => entry.id === fromVariantId);
	if (!source) throw Object.assign(new Error("no such variant on this rule"), { status: 404 });
	const cleanName = String(name ?? "").trim();
	if (!cleanName) throw fail400("a variant needs a name");
	if (rule.variants.some((entry) => entry.name === cleanName)) throw fail400(`this rule already has a variant “${cleanName}”`);
	const next = structuredClone(rule);
	const copy = { ...structuredClone(source), id: newID(), name: cleanName };
	next.variants.push(copy);
	return { rule: next, variant: copy };
}

/** The rule without one variant; the active one can't go (the rule would answer with nothing). */
export function withoutVariant(rule, variantId) {
	if (!(rule.variants ?? []).some((entry) => entry.id === variantId)) throw Object.assign(new Error("no such variant on this rule"), { status: 404 });
	if (rule.activeVariantID === variantId) throw fail400("pick another answer for this rule before deleting this one");
	const next = structuredClone(rule);
	next.variants = next.variants.filter((entry) => entry.id !== variantId);
	return next;
}

function stepFrom(fields) {
	const delay = Math.max(0, Number(fields.delay ?? 0) || 0);
	if (fields.kind === "hang") return { hang: {} };
	if (fields.kind === "fail") {
		const failure = FAILURE_KINDS[fields.failure];
		if (!failure) throw fail400(`failure must be one of ${Object.keys(FAILURE_KINDS).join(", ")}`);
		return { fail: { _0: { errorCode: failure.errorCode, label: failure.label, delay } } };
	}
	const statusCode = Number(fields.statusCode ?? 200);
	if (!Number.isInteger(statusCode) || statusCode < 100 || statusCode > 599) throw fail400("status code must be 100–599");
	const headers = fields.headers && typeof fields.headers === "object" ? fields.headers : JSON_HEADERS;
	const body = String(fields.body ?? "");
	const isJson = Object.entries(headers).some(([key, value]) => key.toLowerCase() === "content-type" && /json/i.test(String(value)));
	if (isJson && body.trim()) {
		try {
			JSON.parse(body);
		} catch (error) {
			throw fail400(`body is not valid JSON: ${error.message}`);
		}
	}
	return { respond: { _0: { body: Buffer.from(body, "utf8").toString("base64"), delay, headers, statusCode } } };
}

function bodyText(base64) {
	if (!base64) return "";
	const text = Buffer.from(base64, "base64").toString("utf8");
	try {
		return JSON.stringify(JSON.parse(text), null, 2);
	} catch {
		return text;
	}
}

// --- Time-shift ---------------------------------------------------------------------------------------

/** Every epoch-millisecond value in a JSON body, with its path (`data.schedules[0].start`) — the anchors to pick from. */
export function timestampsIn(text) {
	const found = [];
	const walk = (node, path) => {
		if (Array.isArray(node)) node.forEach((item, index) => walk(item, `${path}[${index}]`));
		else if (node && typeof node === "object") Object.entries(node).forEach(([key, item]) => walk(item, path ? `${path}.${key}` : key));
		else if (Number.isInteger(node) && node >= MIN_EPOCH_MS && node <= MAX_EPOCH_MS) found.push({ path, value: node });
	};
	try {
		walk(JSON.parse(text), "");
	} catch {
		return [];
	}
	return found;
}

/**
 * Moves every timestamp by one offset so the one at `anchorPath` lands `inSeconds` from `now` ("starts in 20 s",
 * "ends in 30 s"); the gaps between them stay as captured, so tomorrow's slot is still a day later.
 */
export function shiftedBody(text, anchorPath, inSeconds, now = Date.now()) {
	const anchor = timestampsIn(text).find((entry) => entry.path === anchorPath);
	if (!anchor) throw fail400(`no timestamp at ${anchorPath}`);
	const delta = now + Math.round(Number(inSeconds) * 1000) - anchor.value;
	const shift = (node) => {
		if (Array.isArray(node)) return node.map(shift);
		if (node && typeof node === "object") return Object.fromEntries(Object.entries(node).map(([key, item]) => [key, shift(item)]));
		return Number.isInteger(node) && node >= MIN_EPOCH_MS && node <= MAX_EPOCH_MS ? node + delta : node;
	};
	return { body: JSON.stringify(shift(JSON.parse(text)), null, 2), delta };
}

// --- Scenarios (same shape the NetworkLens overlay and MCP write) ---------------------------------------

/** Every rule, on or off, pinned to its current variant: applying it later restores exactly this state. */
export function scenarioFrom(rules, name, group) {
	const cleanName = String(name ?? "").trim();
	if (!cleanName) throw fail400("a scenario needs a name");
	const entries = rules
		.map((rule) => {
			const active = rule.variants?.find((entry) => entry.id === rule.activeVariantID) ?? rule.variants?.[0];
			return active ? { endpointKey: rule.endpointKey, match: rule.match, variantID: active.id, variantName: active.name, isEnabled: rule.isEnabled !== false } : null;
		})
		.filter(Boolean);
	if (!entries.length) throw fail400("no rules with a variant to save");
	return { id: newID(), name: cleanName, ...(group ? { group } : {}), createdAt: toSnapshotDate(undefined), entries };
}

/** The rules a scenario changes (variant by id, then by name — ids differ on another device) and what it can't find. */
export function appliedScenario(rules, scenario) {
	const touched = [];
	const missing = [];
	for (const entry of scenario.entries ?? []) {
		const rule = rules.find((candidate) => sameRule(candidate, entry));
		const variant = rule && (rule.variants.find((candidate) => candidate.id === entry.variantID) ?? rule.variants.find((candidate) => candidate.name === entry.variantName));
		if (!rule || !variant) {
			missing.push(rule ? `${entry.endpointKey} (no variant ${entry.variantName})` : entry.endpointKey);
			continue;
		}
		touched.push({ ...structuredClone(rule), activeVariantID: variant.id, isEnabled: entry.isEnabled });
	}
	return { touched, missing };
}

export function scenarioView(scenario) {
	const entries = scenario.entries ?? [];
	return {
		id: scenario.id,
		name: scenario.name,
		group: scenario.group ?? null,
		armed: entries.filter((entry) => entry.isEnabled).map((entry) => `${entry.endpointKey} → ${entry.variantName}`),
		ruleCount: entries.length,
	};
}

// --- Guardrails ---------------------------------------------------------------------------------------

/**
 * What could make a "bug" that is really a leftover mock: rules armed while mocking is on, armed rules the repo pack
 * doesn't keep (a fixture nobody else can reproduce), and armed variants whose answer differs from the pack's.
 */
export function guardrails({ rules, isMockingEnabled, packRules }) {
	const armed = isMockingEnabled ? rules.filter((rule) => rule.isEnabled !== false) : [];
	const notInPack = [];
	const differsFromPack = [];
	for (const rule of armed) {
		const packed = packRules.get(rule.endpointKey)?.rule;
		const active = rule.variants?.find((entry) => entry.id === rule.activeVariantID);
		if (!packed) {
			notInPack.push(rule.endpointKey);
			continue;
		}
		const packedVariant = packed.variants?.find((entry) => entry.name === active?.name);
		if (active && (!packedVariant || canonical(packedVariant.steps) !== canonical(active.steps))) {
			differsFromPack.push({ endpoint: rule.endpointKey, variant: active.name });
		}
	}
	return { armed: armed.map((rule) => rule.endpointKey), notInPack, differsFromPack, isClean: armed.length === 0 };
}

/** Key order differs between the app's encoder and a pack file, so answers compare with keys sorted. */
function canonical(value) {
	const sorted = (node) => {
		if (Array.isArray(node)) return node.map(sorted);
		if (node && typeof node === "object") return Object.fromEntries(Object.keys(node).sort().map((key) => [key, sorted(node[key])]));
		return node;
	};
	return JSON.stringify(sorted(value));
}

/** Every rule off — the one-click way back to the real backend. */
export function allOff(rules) {
	return rules.filter((rule) => rule.isEnabled !== false).map((rule) => ({ ...structuredClone(rule), isEnabled: false }));
}

/** The device's rules the pack also keeps, replaced by the pack's (device ids kept so scenarios still line up), off. */
export function resetToPack(rules, packRules) {
	return rules
		.filter((rule) => packRules.has(rule.endpointKey))
		.map((rule) => ({ ...structuredClone(packRules.get(rule.endpointKey).rule), id: rule.id, isEnabled: false }));
}
