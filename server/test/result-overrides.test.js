import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
	applyResultOverrides, createResultOverrideStore, effectiveResult, mergeOverrideHistory, overrideEntry, reviewerNotesText, separateCarriedOverrides,
} from "../lib/result-overrides.js";
import { testcaseView } from "../lib/testcase-view.js";
import { buildSession } from "../lib/session-export.js";
import { sessionMarkdown } from "../lib/session-report.js";

const now = new Date("2026-11-02T06:00:00Z");

test("an override needs a known verdict and a description", () => {
	assert.match(overrideEntry({ verdict: "MAYBE", reason: "x" }).error, /verdict/);
	assert.match(overrideEntry({ verdict: "PASS", reason: "   " }).error, /description/);
	assert.match(overrideEntry({ verdict: "PASS", reason: "ok", leniency: "loose" }).error, /leniency/);
	const { entry } = overrideEntry({ verdict: "pass", reason: " Works.\r\n", previousVerdict: "UNDECIDED" }, now);
	assert.deepEqual(entry, { verdict: "PASS", previousVerdict: "UNDECIDED", reason: "Works.", leniency: "strict", at: now.toISOString() });
});

test("the newest override counts until a newer run", () => {
	const history = [{ verdict: "PASS", reason: "ok", at: "2026-11-02T05:00:00Z" }];
	assert.equal(effectiveResult(history, { verdict: "FAIL", at: "2026-11-02T04:00:00Z" }).verdict, "PASS");
	assert.equal(effectiveResult(history, { verdict: "FAIL", at: "2026-11-02T05:30:00Z" }).verdict, "FAIL");
	assert.equal(effectiveResult(history, null).current.verdict, "PASS");
	assert.equal(effectiveResult([], { verdict: "FAIL", at: "x" }).current, null);
});

test("Tests shows the override and keeps the history", () => {
	const cases = applyResultOverrides([{ id: "1", scenario: "A" }, { id: "2", scenario: "B" }], {
		1: [{ verdict: "PASS", previousVerdict: "BLOCKED", reason: "category not needed", leniency: "strict", at: "2026-11-02T05:00:00Z" }],
	});
	const runs = [{ caseId: "1", verdict: "BLOCKED", mode: "run", recordedAt: "2026-10-31T02:00:00Z" }, { caseId: "2", verdict: "FAIL", mode: "run", recordedAt: "2026-10-31T02:00:00Z" }];
	const view = testcaseView({ cases, runs });
	assert.equal(view.cases[0].lastRun.verdict, "PASS");
	assert.equal(view.cases[0].lastRun.mode, "run");
	assert.equal(view.cases[0].lastRun.override.reason, "category not needed");
	assert.equal(view.cases[0].resultOverrides.length, 1);
	assert.equal(view.cases[1].lastRun.verdict, "FAIL");
	assert.deepEqual(view.cases[1].resultOverrides, []);
});

test("bundle cases give their history back to the store, merged without duplicates", async () => {
	const carried = [{ verdict: "PASS", reason: "a", at: "2026-11-02T05:00:00Z" }];
	const { cases, overrides } = separateCarriedOverrides([{ id: "1", resultOverrides: carried }, { id: "2" }]);
	assert.deepEqual(cases, [{ id: "1" }, { id: "2" }]);
	assert.deepEqual(overrides, { 1: carried });
	const store = createResultOverrideStore(join(await mkdtemp(join(tmpdir(), "overrides-")), "result-overrides.json"));
	await store.load();
	await store.append("doc", "1", { verdict: "FAIL", reason: "b", at: "2026-11-02T04:00:00Z" });
	await store.merge("doc", "1", carried);
	await store.merge("doc", "1", carried);
	assert.deepEqual(store.forSource("doc")["1"].map((entry) => entry.verdict), ["FAIL", "PASS"]);
	assert.equal(mergeOverrideHistory(carried, carried).length, 1);
});

test("the run prompt carries the comments and the leniency", () => {
	assert.equal(reviewerNotesText([]), "");
	const text = reviewerNotesText([{ verdict: "FAIL", previousVerdict: "UNDECIDED", reason: "Header must collapse past the trigger.", leniency: "lenient", at: "2026-11-02T05:00:00Z" }]);
	assert.match(text, /Header must collapse past the trigger/);
	assert.match(text, /was UNDECIDED/);
	assert.match(text, /leniently/);
});

test("session export and report carry the override history", () => {
	const history = [{ verdict: "PASS", previousVerdict: "BLOCKED", reason: "category not needed", leniency: "strict", at: "2026-11-02T05:00:00Z" }];
	const doc = { title: "T", source: "s", cases: [{ id: "1", scenario: "A", resultOverrides: history }] };
	const session = buildSession({ doc, history: [{ caseId: "1", verdict: "BLOCKED", mode: "run", recordedAt: "2026-10-31T02:00:00Z" }], now });
	assert.equal(session.cases[0].latest.verdict, "PASS");
	assert.deepEqual(session.cases[0].resultOverrides, history);
	assert.equal(session.summary.overridden, 1);
	assert.match(sessionMarkdown(session), /Result changes[\s\S]*category not needed/);
});
