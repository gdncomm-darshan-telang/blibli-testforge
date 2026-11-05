// D-128: the Network console's edits — variants as fields, time-shift, scenarios, guardrails.
import { test } from "node:test";
import assert from "node:assert/strict";
import {
	allOff, appliedScenario, editedRule, guardrails, resetToPack, ruleView, scenarioFrom, shiftedBody, timestampsIn, withCopiedVariant, withoutVariant,
} from "../lib/lens-console.js";

const b64 = (text) => Buffer.from(text).toString("base64");
const respond = (body, statusCode = 200, delay = 0) => ({ respond: { _0: { body: b64(body), delay, headers: { "Content-Type": "application/json" }, statusCode } } });

function rule(endpointKey = "GET /a", overrides = {}) {
	return {
		id: "R1",
		endpointKey,
		match: {},
		isEnabled: true,
		activeVariantID: "V1",
		variants: [
			{ id: "V1", name: "loaded", exhaustion: "repeatLast", steps: [respond("{\"ok\":true}")] },
			{ id: "V2", name: "timeout", exhaustion: "repeatLast", steps: [{ fail: { _0: { errorCode: -1001, label: "timed out", delay: 0 } } }] },
		],
		...overrides,
	};
}

test("variants read as editor fields, bodies pretty", () => {
	const [loaded, timeout] = ruleView(rule()).variants;
	assert.equal(loaded.kind, "respond");
	assert.equal(loaded.statusCode, 200);
	assert.equal(loaded.body, "{\n  \"ok\": true\n}");
	assert.equal(timeout.kind, "fail");
	assert.equal(timeout.failure, "timedOut");
});

test("an edit rewrites one variant; bad JSON and duplicate names are refused", () => {
	const next = editedRule(rule(), "V1", { kind: "respond", statusCode: 404, delay: 2, body: "{\"items\":[]}", headers: { "Content-Type": "application/json" } });
	const view = ruleView(next).variants[0];
	assert.deepEqual([view.statusCode, view.delay, view.body], [404, 2, "{\n  \"items\": []\n}"]);
	assert.equal(ruleView(rule()).variants[0].statusCode, 200, "original untouched");
	assert.throws(() => editedRule(rule(), "V1", { kind: "respond", body: "{nope", headers: { "Content-Type": "application/json" } }), /not valid JSON/);
	assert.throws(() => editedRule(rule(), "V1", { kind: "respond", name: "timeout", body: "{}" }), /already has a variant/);
	assert.equal(ruleView(editedRule(rule(), "V2", { kind: "fail", failure: "offline" })).variants[1].failure, "offline");
});

test("copying a variant keeps the original and gets a fresh id", () => {
	const { rule: next, variant } = withCopiedVariant(rule(), "V1", "long names");
	assert.equal(next.variants.length, 3);
	assert.notEqual(variant.id, "V1");
	assert.throws(() => withCopiedVariant(rule(), "V1", "loaded"), /already has/);
	assert.equal(withoutVariant(next, variant.id).variants.length, 2);
	assert.throws(() => withoutVariant(next, "V1"), /pick another answer/);
});

test("time-shift lands the anchor N seconds from now and keeps the gaps", () => {
	const start = Date.UTC(2026, 0, 1, 10);
	const text = JSON.stringify({ data: [{ start, end: start + 3_600_000 }], note: 7 });
	assert.deepEqual(timestampsIn(text).map((entry) => entry.path), ["data[0].start", "data[0].end"]);
	const now = Date.UTC(2026, 9, 16, 5);
	const { body } = shiftedBody(text, "data[0].end", 30, now);
	const shifted = JSON.parse(body);
	assert.equal(shifted.data[0].end, now + 30_000);
	assert.equal(shifted.data[0].end - shifted.data[0].start, 3_600_000);
	assert.equal(shifted.note, 7);
	assert.throws(() => shiftedBody(text, "nope", 1, now), /no timestamp/);
});

test("a saved scenario applies back by variant id, then by name", () => {
	const scenario = scenarioFrom([rule("GET /a", { activeVariantID: "V2", isEnabled: false })], "SF timeout");
	assert.deepEqual(scenario.entries.map((entry) => [entry.variantName, entry.isEnabled]), [["timeout", false]]);
	const otherDevice = rule("GET /a", { variants: rule().variants.map((entry) => ({ ...entry, id: `X-${entry.id}` })) });
	const { touched, missing } = appliedScenario([otherDevice], { entries: [...scenario.entries, { endpointKey: "GET /gone", match: {}, variantName: "x" }] });
	assert.equal(touched[0].activeVariantID, "X-V2");
	assert.equal(touched[0].isEnabled, false);
	assert.deepEqual(missing, ["GET /gone"]);
});

test("guardrails name leftovers: not in the pack, differs from the pack; reset turns them off", () => {
	const packed = rule("GET /a");
	const changed = editedRule(rule("GET /a"), "V1", { kind: "respond", body: "{}" });
	const packRules = new Map([["GET /a", { rule: packed }]]);
	const report = guardrails({ rules: [changed, rule("GET /b", { id: "R2" })], isMockingEnabled: true, packRules });
	assert.deepEqual(report.notInPack, ["GET /b"]);
	assert.deepEqual(report.differsFromPack, [{ endpoint: "GET /a", variant: "loaded" }]);
	assert.equal(guardrails({ rules: [changed], isMockingEnabled: false, packRules }).isClean, true);
	const reordered = rule("GET /a", { variants: rule().variants.map((entry) => ({ ...entry, steps: entry.steps.map((step) => JSON.parse(JSON.stringify(step).replace(/"body":("[^"]*"),"delay":0/, '"delay":0,"body":$1'))) })) });
	assert.deepEqual(guardrails({ rules: [reordered], isMockingEnabled: true, packRules }).differsFromPack, [], "key order alone is not a difference");
	assert.deepEqual(allOff([changed]).map((entry) => entry.isEnabled), [false]);
	const [restored] = resetToPack([{ ...changed, id: "DEVICE" }], packRules);
	assert.equal(restored.id, "DEVICE");
	assert.equal(ruleView(restored).variants[0].body, "{\n  \"ok\": true\n}");
});
