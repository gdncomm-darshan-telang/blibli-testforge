import { test } from "node:test";
import assert from "node:assert/strict";
import { buildSession } from "../lib/session-export.js";
import { sessionConfluenceHtml, sessionMarkdown, sessionReportTitle, verdictLabel } from "../lib/session-report.js";

const doc = {
	title: "Microsite Tabbing",
	source: "confluence:1",
	cases: [
		{ id: "7", scenario: "Hidden when no valid tab", steps: "Mock all invalid", expected: "Component hidden", api: "{ \"a\": 1 }" },
		{ id: "11", scenario: "Background | image", expected: "Shown <b>", localEdit: { fields: ["expected"] } },
		{ id: "20", scenario: "Anchor updates" },
		{ id: "30", scenario: "Never run" },
	],
};
const history = [
	{ caseId: "7", mode: "replay", verdict: "FAIL: still visible", recordedAt: "2026-10-31T02:15:52Z", durationMs: 83804, steps: [{ text: "Tap tab", ok: true }, { text: "Wait for hidden", ok: false, reason: "still on screen" }], screenshots: ["/p/7/a.png", "/p/7/b.png"] },
	{ caseId: "7", mode: "replay", verdict: "PASS", recordedAt: "2026-10-30T02:15:52Z" },
	{ caseId: "11", mode: "run", verdict: "PASS", recordedAt: "2026-10-31T03:00:00Z", model: "sonnet", costUsd: 0.48 },
	{ caseId: "20", mode: "run", verdict: "UNDECIDED", recordedAt: "2026-10-31T04:00:00Z" },
];
const session = buildSession({ doc, history, now: new Date("2026-11-01T10:00:00Z"), code: { branch: "qa", codeId: "abc+1" } });

test("verdict labels carry an icon a reader can scan", () => {
	assert.equal(verdictLabel("PASS"), "✅ PASS");
	assert.equal(verdictLabel("FAIL: still visible"), "❌ FAIL");
	assert.equal(verdictLabel("BLOCKED"), "⚠️ BLOCKED", "blocked means it could not be judged, like the summary counts it");
	assert.equal(verdictLabel("UNDECIDED"), "⚠️ UNDECIDED");
	assert.equal(verdictLabel(null), "⚪️ Not run");
});

test("the Markdown report has a summary, attention list, results table and one section per case", () => {
	const markdown = sessionMarkdown(session);
	assert.match(markdown, /^# Microsite Tabbing — test session report/);
	assert.match(markdown, /\| 4 \| 1 \| 1 \| 1 \| 1 \| 33% \| 0 \| 1 \|/);
	assert.match(markdown, /## Needs attention\n\n- \*\*7\*\* · Hidden when no valid tab — ❌ FAIL: still visible\n- \*\*20\*\*/);
	assert.match(markdown, /\| 11 ✎ \| Background \\\| image \| ✅ PASS \| Claude \|/);
	assert.match(markdown, /### 7 · Hidden when no valid tab/);
	assert.match(markdown, /- ✗ Wait for hidden — still on screen/);
	assert.match(markdown, /\*\*Run history\*\*/);
	assert.match(markdown, /!\[b\.png\]\(\/p\/7\/b\.png\)/);
	assert.match(markdown, /```\n\{ "a": 1 \}\n```/);
});

test("images can be left out", () => {
	assert.doesNotMatch(sessionMarkdown(session, { imagePath: () => null }), /!\[/);
});

test("the Confluence HTML escapes text, keeps tables and names proof instead of embedding it", () => {
	const html = sessionConfluenceHtml(session);
	assert.match(html, /<h2>Summary<\/h2>/);
	assert.match(html, /<th>Cases<\/th>/);
	assert.match(html, /Shown &lt;b&gt;/);
	assert.doesNotMatch(html, /<img|ac:structured-macro/);
	assert.match(html, /<strong>Proof<\/strong> \(in the session export\): a\.png, b\.png/);
	assert.match(html, /<li>✗ Wait for hidden — still on screen<\/li>/);
	assert.equal(sessionReportTitle(session), "QA session — Microsite Tabbing — 2026-11-01");
});
