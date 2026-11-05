// A person's override of a case's result (D-180). Like local case edits (D-166) it lives beside the
// document, keyed by document source and case id, and never changes the document. Every override is
// kept as history (oldest first) with the reason the person gave; the newest one counts until a newer
// run replaces it. The reasons and the chosen leniency go into the next Claude run's prompt.
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname } from "node:path";

export const OVERRIDE_VERDICTS = ["PASS", "FAIL", "BLOCKED", "UNDECIDED"];
export const LENIENCIES = ["strict", "lenient"];

const timeOf = (value) => Date.parse(value ?? "") || 0;

/** One history entry, or an error message when the request is not valid. */
export function overrideEntry({ verdict, reason, leniency, previousVerdict = null }, now = new Date()) {
	const upper = String(verdict ?? "").trim().toUpperCase();
	if (!OVERRIDE_VERDICTS.includes(upper)) return { error: `verdict must be one of ${OVERRIDE_VERDICTS.join(", ")}` };
	const text = String(reason ?? "").replace(/\r\n/g, "\n").trim();
	if (!text) return { error: "a description of why the result changes is required" };
	const level = leniency == null || leniency === "" ? "strict" : String(leniency).toLowerCase();
	if (!LENIENCIES.includes(level)) return { error: `leniency must be one of ${LENIENCIES.join(", ")}` };
	return { entry: { verdict: upper, previousVerdict: previousVerdict ?? null, reason: text, leniency: level, at: now.toISOString() } };
}

/** The cases with their override history attached as `resultOverrides` (only cases that have one). */
export function applyResultOverrides(cases, overridesForSource = {}) {
	return cases.map((testCase) => {
		const history = overridesForSource[testCase.id];
		return history?.length ? { ...testCase, resultOverrides: history } : testCase;
	});
}

/**
 * The verdict to show: the newest override when it is at least as new as the newest run, else the run's.
 * `current` is that override (null when a newer run replaced it).
 */
export function effectiveResult(history = [], run = null) {
	const latest = history.at(-1) ?? null;
	const isCurrent = Boolean(latest) && (!run?.at || timeOf(latest.at) >= timeOf(run.at));
	return { verdict: isCurrent ? latest.verdict : run?.verdict ?? null, current: isCurrent ? latest : null };
}

/** Both histories, each entry once (same time and verdict), oldest first. */
export function mergeOverrideHistory(existing = [], incoming = []) {
	const byKey = new Map();
	for (const entry of [...existing, ...incoming]) {
		if (entry?.verdict && entry?.at) byKey.set(`${entry.at}|${entry.verdict}`, entry);
	}
	return [...byKey.values()].sort((first, second) => timeOf(first.at) - timeOf(second.at));
}

/** Cases that arrive with history (a run bundle): the plain cases, and the history to store. */
export function separateCarriedOverrides(cases) {
	const overrides = {};
	const plain = cases.map((testCase) => {
		const { resultOverrides, ...rest } = testCase;
		if (Array.isArray(resultOverrides) && resultOverrides.length) overrides[rest.id] = resultOverrides;
		return rest;
	});
	return { cases: plain, overrides };
}

/** Plain words for the run prompt: the person's reasons and how strictly to judge. Empty without history. */
export function reviewerNotesText(history = []) {
	if (!history.length) return "";
	const notes = history.map((entry) => `${entry.at.slice(0, 10)} set ${entry.verdict}${entry.previousVerdict ? ` (was ${entry.previousVerdict})` : ""}: ${entry.reason.replace(/\s+/g, " ")}`);
	const leniency = history.at(-1).leniency === "lenient"
		? "Judge leniently: the case passes when its main behaviour holds; small visual or wording differences the expected result doesn't name are not failures."
		: "Judge strictly against the expected result.";
	return `The tester reviewed earlier results of this case — take their comments as clarifications of the expected result: ${notes.join(" | ")}. ${leniency}`;
}

export function createResultOverrideStore(file) {
	let overrides = {};
	let saving = Promise.resolve();
	const writeNow = async () => {
		await mkdir(dirname(file), { recursive: true });
		const temp = `${file}.${process.pid}.tmp`;
		await writeFile(temp, `${JSON.stringify(overrides, null, 2)}\n`);
		await rename(temp, file);
	};
	const save = () => {
		saving = saving.catch(() => {}).then(writeNow);
		return saving;
	};
	const put = (source, caseId, history) => {
		const forSource = { ...(overrides[source] ?? {}) };
		if (history.length) forSource[caseId] = history;
		else delete forSource[caseId];
		if (Object.keys(forSource).length) overrides[source] = forSource;
		else delete overrides[source];
	};
	return {
		async load() {
			try {
				const saved = JSON.parse(await readFile(file, "utf8"));
				overrides = saved && typeof saved === "object" ? saved : {};
			} catch {
				overrides = {};
			}
		},
		forSource: (source) => overrides[source] ?? {},
		async append(source, caseId, entry) {
			put(source, caseId, [...(overrides[source]?.[caseId] ?? []), entry]);
			await save();
		},
		/** Adds carried history (a bundle import) without losing any entry already here. */
		async merge(source, caseId, history) {
			put(source, caseId, mergeOverrideHistory(overrides[source]?.[caseId], history));
			await save();
		},
	};
}
