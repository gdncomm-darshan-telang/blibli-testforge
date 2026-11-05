import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdir, mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { caseIdForFolder, caseProof, caseProofFiles } from "../lib/case-proof.js";

test("proof folders map to case ids by name or by number after a prefix", () => {
	const ids = new Set(["3", "21", "25"]);
	assert.equal(caseIdForFolder("3", ids), "3");
	assert.equal(caseIdForFolder("MT-021", ids), "21");
	assert.equal(caseIdForFolder("MT-025-a2", ids), "25");
	assert.equal(caseIdForFolder("MT-099", ids), null);
	assert.equal(caseIdForFolder("demos", ids), null);
});

test("screenshots and videos are counted per case; demos, failures and probes are not proof", async () => {
	const root = await mkdtemp(join(tmpdir(), "proof-"));
	const files = { "3/01.png": "", "21/21.mov": "", "21/01.png": "", "MT-021/MT-021.mov": "", "demos/18/demo-en.mp4": "", "failures/x.png": "", "9/harness-probe.png": "" };
	for (const [path, body] of Object.entries(files)) {
		await mkdir(join(root, path, ".."), { recursive: true });
		await writeFile(join(root, path), body);
	}
	assert.deepEqual(await caseProof(root, ["3", "9", "18", "21"]), { 3: { screenshots: 1, videos: 0 }, 21: { screenshots: 1, videos: 2 } });
	assert.deepEqual(await caseProof(null, ["3"]), {});
	const caseFiles = await caseProofFiles(root, "21");
	assert.deepEqual(caseFiles.map((file) => [file.path.slice(root.length + 1), file.kind]).sort(), [["21/01.png", "image"], ["21/21.mov", "video"], ["MT-021/MT-021.mov", "video"]]);
	assert.deepEqual(await caseProofFiles(root, "18"), []);
});
