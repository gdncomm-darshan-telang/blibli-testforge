import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import { buildSession, sessionFileName, writeSessionExport } from "../lib/session-export.js";

const run = promisify(execFile);

const doc = {
	title: "Test Cases - Microsite Tabbing",
	source: "confluence:1",
	cases: [
		{ id: "11", scenario: "Background image", steps: "Configure it", expected: "Shown", localEdit: { fields: ["expected"] } },
		{ id: "12", scenario: "Broken tab image", steps: "Break it", expected: "Placeholder" },
	],
};
const macros = [{ id: "MT-011", name: "Background image", testCases: ["11"], path: "Engagement/x.json", hasDemoNotes: true }];

function runsWith(shot, video) {
	return [
		{ id: "r2", status: "done", createdAt: "2026-10-31T08:00:00Z", manifest: { branch: "qa", codeId: "abc+1" }, items: [
			{ caseId: "MT-011", macroId: "MT-011", mode: "replay", verdict: "FAIL", endedAt: "2026-10-31T08:01:00Z", durationMs: 79000, review: { action: "override", verdict: "PASS", reason: "doc was wrong" }, evidence: { screenshots: [shot, "/x/harness-probe.png"], videos: [video], summary: "ok" } },
		] },
	];
}

const history = [
	{ caseId: "MT-011", macroId: "MT-011", mode: "replay", verdict: "FAIL", recordedAt: "2026-10-31T08:01:05Z", durationMs: 79000, steps: [{ text: "Tap tab", ok: true, ms: 300 }] },
	{ caseId: "11", mode: "claude", verdict: "PASS", recordedAt: "2026-10-30T08:05:00Z", model: "sonnet", costUsd: 0.4, screenshots: ["/c/claude.png"] },
	{ caseId: "12", mode: "claude", verdict: "UNDECIDED", recordedAt: "2026-10-29T08:05:00Z" },
];

test("the latest verdict is the newest run, overridden by its batch review; history keeps every run", () => {
	const session = buildSession({ doc, history, runs: runsWith("/a.png", "/a.mp4"), macros, now: new Date("2026-11-01T00:00:00Z") });
	const [first, second] = session.cases;
	assert.equal(first.latest.verdict, "PASS", "the override on the same run wins");
	assert.equal(first.latest.review.reason, "doc was wrong");
	assert.deepEqual(first.history.map((entry) => `${entry.ranAs}:${entry.verdict}`), ["replay:FAIL", "claude:PASS"]);
	assert.equal(first.history[1].model, "sonnet");
	assert.equal(first.batchResults[0].runId, "r2");
	assert.equal(first.recording.id, "MT-011");
	assert.deepEqual(first.localEdit, { fields: ["expected"] });
	assert.deepEqual(first.media.screenshots.map((file) => file.path), ["/a.png"], "probe shots are left out");
	assert.equal(second.latest.verdict, "UNDECIDED");
	assert.deepEqual(session.summary, { cases: 2, recorded: 1, editedLocally: 1, overridden: 0, passed: 1, failed: 0, undecided: 1, notRun: 0 });
	assert.deepEqual(session.runs.map((entry) => entry.id), ["r2"]);
});

test("a run newer than any batch keeps its own verdict and proof", () => {
	const newer = [{ caseId: "11", mode: "claude", verdict: "FAIL: wrong image", recordedAt: "2026-11-01T09:00:00Z", screenshots: ["/c/new.png"] }, ...history];
	const [first] = buildSession({ doc, history: newer, runs: runsWith("/a.png", "/a.mp4"), macros }).cases;
	assert.equal(first.latest.verdict, "FAIL: wrong image");
	assert.equal(first.latest.review, undefined);
	assert.deepEqual(first.media.screenshots.map((file) => file.path), ["/c/new.png"]);
});

test("demo videos are attached to their case", () => {
	const demos = [{ caseId: "11", recordedAt: "2026-10-31", videos: { en: "/d/demo-en.mp4", id: null } }];
	const session = buildSession({ doc, runs: [], macros, demos });
	assert.deepEqual(session.cases[0].media.demoVideos, [{ language: "en", path: "/d/demo-en.mp4", recordedAt: "2026-10-31" }]);
});

test("the file name comes from the document title", () => {
	assert.equal(sessionFileName("Test Cases - [Engagement] Tabs", new Date("2026-11-01T10:00:00Z")), "test-cases-engagement-tabs-2026-11-01.zip");
});

test("the zip holds session.json and report.md, plus media only when asked", async () => {
	const dir = await mkdtemp(join(tmpdir(), "session-export-test-"));
	const shot = join(dir, "shot.png");
	await writeFile(shot, "png");
	const list = async (zip) => (await run("unzip", ["-Z1", zip])).stdout.trim().split("\n").sort();

	const plain = await writeSessionExport(buildSession({ doc, history, runs: runsWith(shot, join(dir, "gone.mp4")), macros }), { target: join(dir, "plain.zip") });
	assert.equal(plain.mediaFiles, 0);
	assert.deepEqual(await list(plain.path), ["plain/", "plain/report.md", "plain/session.json"]);

	const withMedia = await writeSessionExport(buildSession({ doc, history, runs: runsWith(shot, join(dir, "gone.mp4")), macros }), { target: join(dir, "media.zip"), includeMedia: true });
	assert.equal(withMedia.mediaFiles, 1);
	assert.deepEqual(withMedia.missingMedia, [join(dir, "gone.mp4")]);
	assert.ok((await list(withMedia.path)).includes("media/media/11/shot.png"));
	const out = join(dir, "out");
	await run("ditto", ["-x", "-k", withMedia.path, out]);
	const saved = JSON.parse(await readFile(join(out, "media", "session.json"), "utf8"));
	assert.equal(saved.cases[0].media.screenshots[0].file, "media/11/shot.png");
	assert.equal(saved.includesMedia, true);
	const report = await readFile(join(out, "media", "report.md"), "utf8");
	assert.match(report, /!\[shot\.png\]\(media\/11\/shot\.png\)/, "the zip's report links media relatively");
});

test("a batch verdict without a review never replaces the verdict Tests shows", () => {
	const runs = [{ id: "b", createdAt: "2026-10-31T02:10:00Z", items: [{ caseId: "12", mode: "replay", verdict: "PASS", endedAt: "2026-10-31T02:15:52Z" }] }];
	const failed = [{ caseId: "12", mode: "replay", verdict: "FAIL", recordedAt: "2026-10-31T02:15:52Z" }];
	const [, second] = buildSession({ doc, history: failed, runs, macros }).cases;
	assert.equal(second.latest.verdict, "FAIL");
	assert.equal(second.batchResults[0].verdict, "PASS");
});
