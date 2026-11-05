// The `testcases` state slice (R3a, D-085): the loaded document's cases, each with the recording that
// replays it (if any) and its latest run, so the Mac app's Tests screen needs no extra requests.
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { effectiveResult } from "./result-overrides.js";
import { coverageOf } from "./staleness.js";

const SUMMARY_FIELDS = ["id", "scenario", "precondition", "steps", "expected", "api", "evidence", "iosStatus"];

/**
 * `macros`: the `/api/macros` list (v2 entries carry `testCases`). `runs`: history, newest first; a
 * replay records the macro id as `caseId`, a Claude run the case id. Only the latest run counts.
 * `staleFor(run, covers)` (F1, D-188) says why that run no longer speaks for the build under test, or null.
 */
export function testcaseView({ title = null, source = null, cases = [], macros = [], runs = [], proof = {}, isLoading = false, staleFor = () => null, ticketsOf = () => [] }) {
	const macroByCase = new Map();
	for (const macro of macros) {
		for (const caseId of macro.testCases ?? []) if (!macroByCase.has(caseId)) macroByCase.set(caseId, { id: macro.id, name: macro.name, usesMocks: Boolean(macro.usesMocks), hasDemoNotes: Boolean(macro.hasDemoNotes), setup: caseSetup(macro.requires), covers: coverageOf(macro) });
	}
	const latestRun = new Map();
	for (const run of runs) {
		for (const key of [run.caseId, run.macroId].filter(Boolean)) if (!latestRun.has(key)) latestRun.set(key, run);
	}
	const lastRunFor = (caseId, macro) => {
		const candidates = [latestRun.get(caseId), macro && latestRun.get(macro.id)].filter(Boolean);
		const run = candidates.sort((first, second) => Date.parse(second.recordedAt ?? 0) - Date.parse(first.recordedAt ?? 0))[0];
		if (!run) return null;
		return { verdict: run.verdict ?? null, mode: run.mode ?? null, at: run.recordedAt ?? null, durationMs: run.durationMs ?? null, build: buildLabel(run.build), stale: staleFor(run, macro?.covers ?? null) };
	};
	return {
		title,
		source,
		isLoading,
		cases: cases.map((testCase) => {
			const summary = Object.fromEntries(SUMMARY_FIELDS.map((field) => [field, testCase[field] ?? null]));
			const macro = macroByCase.get(testCase.id) ?? null;
			// D-180: a person's override counts until a newer run; its history goes along for the detail view.
			const history = testCase.resultOverrides ?? [];
			const run = lastRunFor(testCase.id, macro);
			const { verdict, current } = effectiveResult(history, run);
			const lastRun = current ? { ...(run ?? { mode: null, at: null, durationMs: null }), verdict, override: current } : run;
			// D-182: screenshots and videos filed for the case in the active test batch folder.
			return { ...summary, localEdit: testCase.localEdit ?? null, macro, lastRun, resultOverrides: history, proof: proof[testCase.id] ?? null, tickets: ticketsOf(testCase.id) };
		}),
	};
}

/** "branch @ sha · 15.0.0 (150006)" for a run's build stamp; null when the run carries none. */
export function buildLabel(build) {
	if (!build?.linked) return null;
	const code = build.sha ? build.sha.slice(0, 7) : String(build.builtFrom ?? build.codeId ?? "").split("+")[0];
	const version = build.appVersion ? ` · ${build.appVersion}${build.buildNumber ? ` (${build.buildNumber})` : ""}` : "";
	return `${build.branch ?? "?"} @ ${code}${build.hasLocalChanges ? "+local" : ""}${version}`;
}

/** Keeps the last loaded document across server restarts (it used to live only in memory). */
export function createLoadedDocStore(file) {
	return {
		async read() {
			try {
				const saved = JSON.parse(await readFile(file, "utf8"));
				return Array.isArray(saved?.cases) ? saved : null;
			} catch {
				return null;
			}
		},
		async write({ source, title, cases, jira = null }) {
			await mkdir(dirname(file), { recursive: true });
			const temp = `${file}.${process.pid}.tmp`;
			await writeFile(temp, JSON.stringify({ source, title, cases, jira, savedAt: new Date().toISOString() }));
			await rename(temp, file);
		},
	};
}

const START_SCREEN_LABELS = { home: "Home", anyScreen: "Any screen", freshLaunch: "Fresh launch" };
const ENVIRONMENT_LABELS = { prod: "PROD", uatb: "UAT B", preprod: "PRE PROD" };

/** D-185: where a replay starts and what it needs from the app, in words; null when the recording states nothing. */
export function caseSetup(requires) {
	if (!requires) return null;
	const needs = [
		requires.environment && (ENVIRONMENT_LABELS[requires.environment] ?? requires.environment),
		requires.session === "loggedIn" && "Logged in",
		requires.session === "loggedOut" && "Logged out",
		requires.networkLens && "NetworkLens on",
	].filter(Boolean);
	const startScreen = requires.startScreen ? START_SCREEN_LABELS[requires.startScreen] ?? requires.startScreen : null;
	return startScreen || needs.length ? { startScreen, needs } : null;
}
