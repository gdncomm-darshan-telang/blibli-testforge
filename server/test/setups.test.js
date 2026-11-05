import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { SetupStore, makeSetup, needsPrepare } from "../lib/setups.js";

const fields = {
	name: "Flash Sale regression",
	code: { source: "github", repo: "/r", branch: "develop" },
	doc: { source: "https://example.atlassian.net/wiki/pages/1", title: "SF cases" },
	caseIds: ["SF-084", "SF-084", "HM-901"],
};

test("P9: a setup needs a name, prepared code, a loaded document and ticked cases", () => {
	assert.deepEqual(makeSetup(fields).caseIds, ["SF-084", "HM-901"]);
	assert.equal(makeSetup(fields).approval, "ask");
	assert.throws(() => makeSetup({ ...fields, name: " " }), /name/);
	assert.throws(() => makeSetup({ ...fields, code: null }), /prepare the code/);
	assert.throws(() => makeSetup({ ...fields, doc: null }), /load the test cases/);
	assert.throws(() => makeSetup({ ...fields, caseIds: [] }), /tick the cases/);
	// A local folder has no branch to keep.
	assert.equal(makeSetup({ ...fields, code: { source: "local", repo: "/r", branch: "x" } }).code.branch, undefined);
});

test("P9: Run again prepares only when the code isn't already what the setup names", () => {
	const local = makeSetup({ ...fields, code: { source: "local", repo: "/r" } });
	const manifest = { source: "local", repo: "/r" };
	assert.equal(needsPrepare(local, null, null), true);
	assert.equal(needsPrepare(local, manifest, { hasDrifted: false }), false);
	assert.equal(needsPrepare(local, manifest, { hasDrifted: true }), true);
	assert.equal(needsPrepare(local, { ...manifest, repo: "/other" }, null), true);
	// A GitHub branch always means its latest commit.
	assert.equal(needsPrepare(makeSetup(fields), { source: "github", repo: "/r", branch: "develop" }, null), true);
});

test("P9: saving under an existing name replaces it and keeps its id", async () => {
	const store = new SetupStore(await mkdtemp(join(tmpdir(), "setups-")));
	const first = await store.save(fields);
	const again = await store.save({ ...fields, name: "flash sale REGRESSION", caseIds: ["SF-001"] });
	assert.equal(again.id, first.id);
	assert.deepEqual((await store.list()).map((setup) => setup.caseIds), [["SF-001"]]);
	await store.noteRun(first.id, { batchId: "b1" });
	assert.equal((await store.get(first.id)).lastRun.batchId, "b1");
	assert.equal(await store.remove(first.id), true);
	assert.equal(await store.remove(first.id), false);
});
