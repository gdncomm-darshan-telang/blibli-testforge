import { test } from "node:test";
import assert from "node:assert/strict";
import { runFields, runGenerate } from "../lib/model-fuzz-io.js";
import { newID, variant } from "../lib/variants.js";

const SWIFT_SOURCE = `
struct FSThingResponse: Codable {
    let id: String?
    let title: String?

    enum CodingKeys: String, CodingKey { case id, title }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        title = try values.decodeIfPresent(String.self, forKey: .title)
    }
}
`;

function makePackJson() {
	const envelope = { code: 200, status: "OK", data: [{ id: "A", title: "Hello" }] };
	const loaded = variant("loaded", [{ respond: { _0: { body: Buffer.from(JSON.stringify(envelope)).toString("base64"), delay: 0, headers: {}, statusCode: 200 } } }]);
	const rule = { id: newID(), endpointKey: "GET /backend/thing", match: { query: {}, headers: {} }, variants: [loaded], activeVariantID: loaded.id, isEnabled: false };
	return { formatVersion: 1, name: rule.endpointKey, notes: "", createdAt: "2026-01-01T00:00:00.000Z", mocks: [rule], scenarios: [] };
}

/** An in-memory fs: `files` maps path -> string content. `calls` records every deps method invoked. */
function fakeDeps(files) {
	const calls = [];
	const deps = {
		readFile: async (path) => {
			calls.push(`read:${path}`);
			if (!(path in files)) throw Object.assign(new Error(`ENOENT: ${path}`), { code: "ENOENT" });
			return files[path];
		},
		writeFile: async (path, data) => {
			calls.push(`write:${path}`);
			files[path] = data;
		},
		rename: async (from, to) => {
			calls.push(`rename:${from}->${to}`);
			files[to] = files[from];
			delete files[from];
		},
		findDeclaringFile: async (typeName, root) => {
			calls.push(`find:${typeName}@${root}`);
			return Object.keys(files).filter((path) => path.endsWith(".swift") && files[path].includes(`struct ${typeName}`));
		},
	};
	return { deps, calls, files };
}

test("runFields resolves the type to a file via findDeclaringFile when --file is omitted", async () => {
	const { deps, calls } = fakeDeps({ "App/FSThingResponse.swift": SWIFT_SOURCE });
	const result = await runFields({ type: "FSThingResponse", root: "App" }, deps);
	assert.equal(result.swiftPath, "App/FSThingResponse.swift");
	assert.equal(result.fields.length, 2);
	assert.deepEqual(calls, ["find:FSThingResponse@App", "read:App/FSThingResponse.swift"]);
});

test("runFields skips findDeclaringFile entirely when --file is given", async () => {
	const { deps, calls } = fakeDeps({ "explicit.swift": SWIFT_SOURCE });
	const result = await runFields({ type: "FSThingResponse", file: "explicit.swift" }, deps);
	assert.equal(result.swiftPath, "explicit.swift");
	assert.deepEqual(calls, ["read:explicit.swift"]);
});

test("runFields reports no match clearly, naming the repo-index skill as the alternative", async () => {
	const { deps } = fakeDeps({});
	await assert.rejects(runFields({ type: "NoSuchType", root: "." }, deps), /repo-index skill/);
});

test("runFields reports an ambiguous match, naming every candidate", async () => {
	const { deps } = fakeDeps({ "A/x.swift": SWIFT_SOURCE, "B/y.swift": SWIFT_SOURCE });
	await assert.rejects(runFields({ type: "FSThingResponse", root: "." }, deps), /more than one file declares/);
});

test("runGenerate: dry-run computes and reports, but never calls writeFile/rename", async () => {
	const { deps, calls, files } = fakeDeps({ "App/FSThingResponse.swift": SWIFT_SOURCE, "pack.json": JSON.stringify(makePackJson()) });
	const result = await runGenerate({ type: "FSThingResponse", root: "App", pack: "pack.json", dryRun: true }, deps);
	assert.equal(result.written.length, 2); // fuzz-missing-id, fuzz-missing-title
	assert.equal(result.outPath, "pack.json");
	assert.ok(!calls.some((c) => c.startsWith("write:") || c.startsWith("rename:")));
	assert.equal(JSON.parse(files["pack.json"]).mocks[0].variants.length, 1, "the pack on disk must be untouched by a dry run");
});

test("runGenerate: a real run writes atomically (temp file then rename) and the final file has the merged pack", async () => {
	const { deps, calls, files } = fakeDeps({ "App/FSThingResponse.swift": SWIFT_SOURCE, "pack.json": JSON.stringify(makePackJson()) });
	await runGenerate({ type: "FSThingResponse", root: "App", pack: "pack.json" }, deps);
	assert.ok(calls.some((c) => c.startsWith("write:pack.json.tmp-")));
	assert.ok(calls.some((c) => c.startsWith("rename:pack.json.tmp-")));
	assert.ok(!("pack.json.tmp-" in files) && !Object.keys(files).some((p) => p.includes(".tmp-")), "the temp file must not remain");
	const merged = JSON.parse(files["pack.json"]);
	const names = merged.mocks[0].variants.map((v) => v.name);
	assert.ok(names.includes("loaded") && names.includes("fuzz-missing-id") && names.includes("fuzz-missing-title"));
});

test("runGenerate: --out writes to a different path and leaves --pack untouched", async () => {
	const { deps, files } = fakeDeps({ "App/FSThingResponse.swift": SWIFT_SOURCE, "pack.json": JSON.stringify(makePackJson()) });
	const originalPack = files["pack.json"];
	await runGenerate({ type: "FSThingResponse", root: "App", pack: "pack.json", out: "scratch.json" }, deps);
	assert.equal(files["pack.json"], originalPack);
	assert.ok("scratch.json" in files);
});
