import { test } from "node:test";
import assert from "node:assert/strict";
import { newID, variant } from "../lib/variants.js";
import {
	readAtPath, writeAtPath, locateInstances, decodeBaselineVariant,
	generateFieldVariants, selectRule, mergeGeneratedVariants,
} from "../lib/model-fuzz.js";

// Field list matching the real FSSubFlashsaleRangeItemResponse shape (name/jsonKey differ only for
// isTimeBased, mirroring its CodingKeys remap), plus one enum field (FSQuotaStatus isn't actually
// on this struct — added here only to exercise the enum-variant path end to end).
const FIELDS = [
	{ name: "start", jsonKey: "start", kind: "scalar", isArray: false, isOptional: true },
	{ name: "id", jsonKey: "id", kind: "scalar", isArray: false, isOptional: true },
	{ name: "isTimeBased", jsonKey: "timeBased", kind: "scalar", isArray: false, isOptional: true },
	{ name: "background", jsonKey: "background", kind: "opaque", isArray: false, isOptional: true },
	{ name: "products", jsonKey: "products", kind: "opaque", isArray: true, isOptional: true },
	{ name: "status", jsonKey: "status", kind: "enum", isArray: false, isOptional: true, enumCases: [{ name: "available", raw: "AVAILABLE" }, { name: "limited", raw: "LIMITED" }] },
	{ name: "odd", jsonKey: null, kind: "unparsed", isArray: false, isOptional: null },
];

const ITEM = { start: 1791778715789, id: "QA-SUBFS-A", timeBased: true, background: { start: "#000" }, products: [{ sku: "A" }], status: "AVAILABLE" };

function bodyBuffer(json) {
	return Buffer.from(JSON.stringify(json), "utf8");
}

function makePack() {
	const envelopeBody = { code: 200, status: "OK", data: [structuredClone(ITEM), structuredClone(ITEM)] };
	const loaded = variant("loaded", [{ respond: { _0: { body: bodyBuffer(envelopeBody).toString("base64"), delay: 0, headers: {}, statusCode: 200 } } }]);
	const timeout = { id: newID(), name: "timeout", steps: [{ fail: { _0: { errorCode: -1001, label: "timed out", delay: 0 } } }], exhaustion: "repeatLast" };
	const invertMode = variant("invert-mode", [{ respond: { _0: { body: bodyBuffer(envelopeBody).toString("base64"), delay: 0, headers: {}, statusCode: 200 } } }]);
	const rule = {
		id: newID(),
		endpointKey: "GET /backend/content-api/sub-flashsale/range",
		match: { query: {}, headers: {} },
		variants: [loaded, timeout, invertMode],
		activeVariantID: loaded.id,
		isEnabled: false,
	};
	return { formatVersion: 1, name: rule.endpointKey, notes: "", createdAt: "2026-01-01T00:00:00.000Z", mocks: [rule], scenarios: [] };
}

test("readAtPath / writeAtPath round-trip through a dot path", () => {
	const body = { data: [{ a: 1 }] };
	assert.equal(readAtPath(body, "data.0.a"), 1);
	const updated = writeAtPath(body, "data.0.a", 2);
	assert.equal(updated.data[0].a, 2);
	assert.equal(body.data[0].a, 1, "the original body must not be mutated");
});

test("locateInstances finds the envelope's data array automatically", () => {
	const body = { code: 200, status: "OK", data: [ITEM, ITEM] };
	const located = locateInstances(body, FIELDS);
	assert.deepEqual(located, { path: "data", kind: "array" });
});

test("locateInstances uses the body itself when it already looks like an instance", () => {
	const located = locateInstances(ITEM, FIELDS);
	assert.deepEqual(located, { path: "", kind: "single" });
});

test("locateInstances throws listing top-level keys when nothing matches", () => {
	assert.throws(() => locateInstances({ unrelated: true }, FIELDS), /pass --at/);
});

test("--at bypasses the search entirely", () => {
	const body = { nested: { weird: [ITEM] } };
	const located = locateInstances(body, FIELDS, "nested.weird");
	assert.deepEqual(located, { path: "nested.weird", kind: "array" });
});

test("decodeBaselineVariant decodes the loaded variant's base64 body and carries statusCode/headers/delay/exhaustion", () => {
	const pack = makePack();
	const rule = pack.mocks[0];
	const baseline = decodeBaselineVariant(rule, "loaded");
	assert.equal(baseline.bodyJson.data.length, 2);
	assert.equal(baseline.statusCode, 200);
	assert.equal(baseline.exhaustion, "repeatLast");
});

test("decodeBaselineVariant refuses a variant with no respond step", () => {
	const pack = makePack();
	assert.throws(() => decodeBaselineVariant(pack.mocks[0], "timeout"), /doesn't respond with a body/);
});

test("generateFieldVariants: missing-<field> for every resolvable field, empty-<field> for arrays, enum cases + unknown-value for enums, nothing for an unparsed field", () => {
	const body = { data: [structuredClone(ITEM), structuredClone(ITEM)] };
	const located = locateInstances(body, FIELDS);
	const baseline = { statusCode: 200, headers: {}, delay: 0, exhaustion: "repeatLast" };
	const generated = generateFieldVariants(FIELDS, body, located, baseline);
	const names = generated.map((v) => v.name).sort();
	assert.deepEqual(names, [
		"fuzz-empty-products",
		"fuzz-enum-status-available",
		"fuzz-enum-status-limited",
		"fuzz-enum-status-unknown-value",
		"fuzz-missing-background",
		"fuzz-missing-id",
		"fuzz-missing-isTimeBased",
		"fuzz-missing-products",
		"fuzz-missing-start",
		"fuzz-missing-status",
	].sort());
});

test("generateFieldVariants targets the wire key, not the property name — isTimeBased is removed via its timeBased key, every instance", () => {
	const body = { data: [structuredClone(ITEM), structuredClone(ITEM)] };
	const located = locateInstances(body, FIELDS);
	const baseline = { statusCode: 200, headers: {}, delay: 0, exhaustion: "repeatLast" };
	const generated = generateFieldVariants(FIELDS, body, located, baseline);
	const missing = generated.find((v) => v.name === "fuzz-missing-isTimeBased");
	const decoded = JSON.parse(Buffer.from(missing.steps[0].respond._0.body, "base64").toString("utf8"));
	for (const item of decoded.data) {
		assert.ok(!("timeBased" in item));
		assert.ok("start" in item, "other fields on the same instance must be untouched");
	}
});

test("generateFieldVariants mutates every instance in an array, not just the first", () => {
	const body = { data: [structuredClone(ITEM), structuredClone(ITEM)] };
	const located = locateInstances(body, FIELDS);
	const baseline = { statusCode: 200, headers: {}, delay: 0, exhaustion: "repeatLast" };
	const generated = generateFieldVariants(FIELDS, body, located, baseline);
	const missing = generated.find((v) => v.name === "fuzz-missing-id");
	const decoded = JSON.parse(Buffer.from(missing.steps[0].respond._0.body, "base64").toString("utf8"));
	assert.equal(decoded.data.length, 2);
	assert.ok(decoded.data.every((item) => !("id" in item)));
});

test("selectRule: a single-rule pack is used automatically, and a mismatched --endpoint is refused", () => {
	const pack = makePack();
	assert.equal(selectRule(pack, {}), pack.mocks[0]);
	assert.throws(() => selectRule(pack, { endpointKey: "GET /something/else" }), /not "GET \/something\/else"/);
});

test("selectRule: a multi-rule pack requires --endpoint or --rule-id", () => {
	const pack = makePack();
	const secondRule = { ...pack.mocks[0], id: newID(), endpointKey: "GET /backend/content-api/flashsale" };
	pack.mocks.push(secondRule);
	assert.throws(() => selectRule(pack, {}), /has 2 rules/);
	assert.equal(selectRule(pack, { endpointKey: secondRule.endpointKey }), secondRule);
});

test("mergeGeneratedVariants: hand-authored and standard variants are untouched, activeVariantID/isEnabled survive", () => {
	const pack = makePack();
	const rule = pack.mocks[0];
	const generated = [{ id: newID(), name: "fuzz-missing-id", steps: [{ respond: { _0: { body: "e30=", delay: 0, headers: {}, statusCode: 200 } } }], exhaustion: "repeatLast" }];
	const merged = mergeGeneratedVariants(pack, { ruleId: rule.id }, generated);
	const updatedRule = merged.mocks[0];
	const names = updatedRule.variants.map((v) => v.name);
	assert.ok(names.includes("loaded") && names.includes("timeout") && names.includes("invert-mode"));
	assert.ok(names.includes("fuzz-missing-id"));
	assert.equal(updatedRule.activeVariantID, rule.activeVariantID);
	assert.equal(updatedRule.isEnabled, rule.isEnabled);
	assert.deepEqual(updatedRule.variants.find((v) => v.name === "invert-mode"), rule.variants.find((v) => v.name === "invert-mode"));
});

test("mergeGeneratedVariants is idempotent and keeps a recurring generated variant's id stable", () => {
	const pack = makePack();
	const rule = pack.mocks[0];
	const first = [{ id: newID(), name: "fuzz-missing-id", steps: [{ respond: { _0: { body: "e30=", delay: 0, headers: {}, statusCode: 200 } } }], exhaustion: "repeatLast" }];
	const once = mergeGeneratedVariants(pack, { ruleId: rule.id }, first);
	const firstId = once.mocks[0].variants.find((v) => v.name === "fuzz-missing-id").id;

	const second = [{ id: newID(), name: "fuzz-missing-id", steps: first[0].steps, exhaustion: "repeatLast" }];
	const twice = mergeGeneratedVariants(once, { ruleId: rule.id }, second);
	const secondId = twice.mocks[0].variants.find((v) => v.name === "fuzz-missing-id").id;

	assert.equal(secondId, firstId, "regenerating the same named variant must not dangle activeVariantID elsewhere");
	assert.equal(twice.mocks[0].variants.length, once.mocks[0].variants.length, "regeneration replaces, never appends a duplicate");
});

test("mergeGeneratedVariants drops a generated variant whose field no longer exists on re-generation", () => {
	const pack = makePack();
	const rule = pack.mocks[0];
	const first = [
		{ id: newID(), name: "fuzz-missing-id", steps: [{ respond: { _0: { body: "e30=", delay: 0, headers: {}, statusCode: 200 } } }], exhaustion: "repeatLast" },
		{ id: newID(), name: "fuzz-missing-start", steps: [{ respond: { _0: { body: "e30=", delay: 0, headers: {}, statusCode: 200 } } }], exhaustion: "repeatLast" },
	];
	const once = mergeGeneratedVariants(pack, { ruleId: rule.id }, first);
	const second = [first[0]]; // "start" field removed from the model since
	const twice = mergeGeneratedVariants(once, { ruleId: rule.id }, second);
	const names = twice.mocks[0].variants.map((v) => v.name);
	assert.ok(!names.includes("fuzz-missing-start"));
	assert.ok(names.includes("fuzz-missing-id"));
});
