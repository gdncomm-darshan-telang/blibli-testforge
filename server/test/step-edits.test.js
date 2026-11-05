import { test } from "node:test";
import assert from "node:assert/strict";
import { applyStepEdits, editableFields } from "../lib/step-edits.js";
import { macroInputs, mockResponse } from "../lib/macro-inputs.js";

const macro = { id: "mc_1", name: "M", steps: [
	{ id: "a", do: "tap", el: "el_1" },
	{ id: "b", do: "wait", seconds: 2 },
	{ id: "c", do: "type", el: "el_2", text: "hi" },
] };

test("D-195: reorder, remove and edit keep everything else in a step", () => {
	const edited = applyStepEdits(macro, { order: ["c", "a"], changes: { a: { timeout: 3, optional: true }, c: { text: "hello" } } });
	assert.deepEqual(edited.steps, [{ id: "c", do: "type", el: "el_2", text: "hello" }, { id: "a", do: "tap", el: "el_1", timeout: 3, optional: true }]);
	assert.throws(() => applyStepEdits(macro, { order: ["a", "x"] }), /no step x/);
	assert.throws(() => applyStepEdits(macro, { order: ["a"], changes: { a: { text: "no" } } }), /can't be changed/);
	assert.throws(() => applyStepEdits(macro, { order: ["a"], changes: { a: { timeout: -1 } } }), /isn't a valid timeout/);
	assert.throws(() => applyStepEdits(macro, { order: [] }), /at least one step/);
	assert.deepEqual(editableFields({ do: "relaunch" }), []);
});

test("D-195: a recording's deeplinks and mocks, and the armed variant's decoded body", () => {
	const inputs = macroInputs([
		{ do: "openDeeplink", url: "blibli://a" },
		{ do: "mock", endpoint: "GET /x", variant: "empty", atLaunch: true },
		{ do: "openDeeplink", url: "blibli://a" },
		{ do: "mock", endpoint: "GET /x", enabled: false },
	]);
	assert.deepEqual(inputs, { deeplinks: ["blibli://a"], mocks: [
		{ endpoint: "GET /x", variant: "empty", isOff: false, atLaunch: true },
		{ endpoint: "GET /x", variant: null, isOff: true, atLaunch: false },
	] });
	const rules = [{ endpointKey: "GET /x", variants: [{ name: "empty", steps: [{ respond: { _0: { status: 200, body: Buffer.from("{\"data\":[]}").toString("base64"), headers: { "Content-Type": "application/json" } } } }] }] }];
	assert.deepEqual(mockResponse(rules, "GET /x", "empty"), { status: 200, contentType: "application/json", body: "{\"data\":[]}", endpointKey: "GET /x" });
	assert.equal(mockResponse(rules, "GET /x", "missing"), null);
});
