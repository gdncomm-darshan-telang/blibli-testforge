import { test } from "node:test";
import assert from "node:assert/strict";
import { checkInterceptor } from "../lib/lens-check.js";

const live = (outcome) => async () => ({ ok: true, outcome });
const notLive = async () => ({ ok: false, error: "no app" });

test("mocking ON with no rules is flagged", async () => {
	const check = await checkInterceptor({ live: live({ isMockingEnabled: true, rules: [] }) });
	assert.equal(check.source, "running app");
	assert.equal(check.suspicious, true);
	assert.match(check.lines.join("\n"), /ON with no enabled rule/);
});

test("armed rules are listed; disabled ones are not", async () => {
	const rules = [{ endpointKey: "GET /a", isEnabled: true }, { endpointKey: "GET /b", isEnabled: false }];
	const check = await checkInterceptor({ live: live({ isMockingEnabled: true, rules }) });
	assert.deepEqual(check.armed, ["GET /a"]);
	assert.match(check.lines.join("\n"), /armed: GET \/a/);
});

test("mocking OFF is clean, even with enabled rules", async () => {
	const check = await checkInterceptor({ live: live({ isMockingEnabled: false, rules: [{ endpointKey: "GET /a", isEnabled: true }] }) });
	assert.equal(check.suspicious, false);
	assert.deepEqual(check.armed, []);
});

test("falls back to the session file when the app doesn't answer", async () => {
	const check = await checkInterceptor({ live: notLive, fromFile: async () => ({ isMockingEnabled: true, rules: [] }) });
	assert.match(check.source, /session file/);
	assert.equal(check.suspicious, true);
});

test("unknown when neither answers", async () => {
	const check = await checkInterceptor({ live: notLive, fromFile: async () => { throw new Error("x"); } });
	assert.equal(check.known, false);
});

test("with a trace: only mocks that answered during the run are causes", async () => {
	const rules = [{ endpointKey: "GET /flashsale", isEnabled: true }, { endpointKey: "POST /gdn-oauth/token", isEnabled: true }];
	const served = { "POST /gdn-oauth/token": 2 };
	const check = await checkInterceptor({ live: live({ isMockingEnabled: true, rules }), served, touched: ["POST /gdn-oauth/token"] });
	const text = check.lines.join("\n");
	assert.equal(check.suspicious, true);
	assert.match(text, /answered 2 request\(s\) with a mock: POST \/gdn-oauth\/token \(set up by this test\)/);
	assert.match(text, /armed but not called during this run \(can't explain it\): GET \/flashsale/);
});

test("with a trace and nothing served: not suspicious, says so", async () => {
	const check = await checkInterceptor({ live: live({ isMockingEnabled: true, rules: [{ endpointKey: "GET /flashsale", isEnabled: true }] }), served: {} });
	assert.equal(check.suspicious, false);
	assert.match(check.lines.join("\n"), /no mocked response during this run/);
});

test("a mock nobody in this test set up is called out", async () => {
	const check = await checkInterceptor({ live: notLive, fromFile: async () => null, served: { "GET /flashsale": 1 }, touched: [] });
	assert.match(check.lines.join("\n"), /NOT set up by this test/);
});

test("mockServedSince counts mock-served exchanges after the start", async () => {
	const { mockServedSince } = await import("../lib/lens-check.js");
	const records = [
		{ recordedAt: "2026-10-12T01:00:00Z", exchange: { isMockServed: true, endpointKey: "GET /a" } },
		{ recordedAt: "2026-10-12T02:00:00Z", exchange: { isMockServed: true, endpointKey: "GET /a" } },
		{ recordedAt: "2026-10-12T02:00:01Z", exchange: { isMockServed: false, endpointKey: "GET /b" } },
	];
	assert.deepEqual(mockServedSince(records, Date.parse("2026-10-12T01:30:00Z")), { "GET /a": 1 });
});
