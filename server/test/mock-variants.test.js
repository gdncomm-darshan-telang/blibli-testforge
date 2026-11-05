import { test } from "node:test";
import assert from "node:assert/strict";
import { matchVariant, variantsArmedBy, variantsServed } from "../lib/mock-variants.js";

const b64 = (text) => Buffer.from(text).toString("base64");
const respond = (status, text) => ({ respond: { _0: { statusCode: status, body: b64(text) } } });
const rule = {
	endpointKey: "GET /promo",
	variants: [
		{ name: "loaded", steps: [respond(200, '{"data":[1,2,3]}')] },
		{ name: "empty", steps: [respond(200, '{"data":[]}')] },
		{ name: "same-size-a", steps: [respond(200, "aaaa")] },
		{ name: "same-size-b", steps: [respond(200, "bbbb")] },
		{ name: "500", steps: [respond(500, '{"code":500}')] },
		{ name: "timeout", steps: [{ fail: { _0: "timedOut" } }] },
	],
};
const served = (at, text, { status = 200, truncated = false, bytes } = {}) => ({
	recordedAt: at,
	exchange: { isMockServed: true, endpointKey: "GET /promo", response: { statusCode: status, body: b64(text), bodyTruncated: truncated, originalBodyByteCount: bytes ?? Buffer.byteLength(text) } },
});

test("match: same bytes win; a changed body falls back to status + size; failures match failing variants", () => {
	assert.deepEqual(matchVariant(served(0, '{"data":[]}').exchange, rule), { variants: ["empty"], match: "exact" });
	// Retimed or redacted: same length, different bytes.
	assert.deepEqual(matchVariant(served(0, '{"data":[9,9,9]}').exchange, rule), { variants: ["loaded"], match: "size" });
	assert.deepEqual(matchVariant(served(0, "cccc").exchange, rule), { variants: ["same-size-a", "same-size-b"], match: "size" });
	assert.deepEqual(matchVariant({ isMockServed: true }, rule), { variants: ["timeout"], match: "failure" });
	assert.deepEqual(matchVariant(served(0, "zz", { status: 404 }).exchange, rule), { variants: [], match: null });
});

test("served: one row per variant in the window, counted; ambiguity is kept, never guessed", () => {
	const records = [
		served("2026-10-31T10:00:00Z", '{"data":[]}'),
		served("2026-10-31T10:00:05Z", '{"data":[]}'),
		served("2026-10-31T10:00:09Z", "cccc"),
		served("2026-10-31T11:00:00Z", '{"data":[1,2,3]}'),
		{ recordedAt: "2026-10-31T10:00:01Z", exchange: { isMockServed: false, endpointKey: "GET /promo" } },
	];
	const rows = variantsServed(records, [rule], { since: Date.parse("2026-10-31T09:59:00Z"), until: Date.parse("2026-10-31T10:30:00Z") });
	assert.deepEqual(rows, [
		{ endpoint: "GET /promo", variant: "empty", match: "exact", count: 2 },
		{ endpoint: "GET /promo", variant: null, match: "ambiguous", count: 1, candidates: ["same-size-a", "same-size-b"] },
	]);
	assert.deepEqual(variantsServed(records, [], {}).map((row) => [row.variant, row.count]), [[null, 4]]);
});

test("armed: a macro's mock steps in order, switch-offs and repeats left out", () => {
	const steps = [
		{ do: "mock", endpoint: "GET /promo", variant: "loaded" },
		{ do: "tap", el: "el_X" },
		{ do: "mock", endpoint: "GET /promo", variant: "empty" },
		{ do: "mock", endpoint: "GET /promo", variant: "loaded" },
		{ do: "mock", endpoint: "GET /promo", enabled: false },
	];
	assert.deepEqual(variantsArmedBy(steps), [
		{ endpoint: "GET /promo", variant: "loaded", match: "macro" },
		{ endpoint: "GET /promo", variant: "empty", match: "macro" },
	]);
});

test("served: two rules for one endpoint (an old one switched off) are matched together", () => {
	const old = { endpointKey: "GET /promo", variants: [{ name: "loaded", steps: [respond(200, "old")] }] };
	const rows = variantsServed([served("2026-10-31T10:00:00Z", '{"data":[]}')], [rule, old]);
	assert.equal(rows[0].variant, "empty");
});

test("match: same body with a different delay is told apart by the trace's time", () => {
	const delayed = (name, delay) => ({ name, steps: [{ respond: { _0: { statusCode: 200, body: b64("same"), delay } } }] });
	const timed = { endpointKey: "GET /promo", variants: [delayed("loaded", 0), delayed("slow", 3)] };
	const exchange = (total) => ({ ...served(0, "same").exchange, timing: { total } });
	assert.deepEqual(matchVariant(exchange(0.000002), timed), { variants: ["loaded"], match: "exact+timing" });
	assert.deepEqual(matchVariant(exchange(3.1), timed), { variants: ["slow"], match: "exact+timing" });
	assert.deepEqual(matchVariant(served(0, "same").exchange, timed).variants, ["loaded", "slow"]);
});
