// D-129: tracker fires, contract checks and the DA markdown — the JS port of extract_trackers.py.
import { test } from "node:test";
import assert from "node:assert/strict";
import { contractProblems, trackerDetail, trackerFires, trackerMarkdown, trackerSummary, trmsIdsIn, valuesAt } from "../lib/lens-trackers.js";

const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64");

const fire = (id, sessionID, startedAt, payload, statusCode = 200) => ({
	sessionID,
	recordedAt: startedAt,
	exchange: {
		id,
		endpointKey: "POST /track",
		startedAt,
		request: { method: "POST", url: "https://x/track", body: encode({ app_version: "9.1", payload }) },
		response: { statusCode },
	},
});

const records = [
	fire("a", "old", "2026-10-16T05:00:00Z", { trms_id: "ENG-1", event: "view" }),
	fire("b", "new", "2026-10-16T06:00:02Z", { trms_id: "ENG-1", event: "view", origin_screen: "home", items: [{ item_id: "1" }, { item_id: "" }] }),
	fire("c", "new", "2026-10-16T06:00:01Z", { trms_id: "ENG-2", event: "click", origin_screen: "home" }, 500),
	{ sessionID: "new", recordedAt: "2026-10-16T06:00:03Z", exchange: { id: "d", request: { body: encode({ hello: "world" }) } } },
];

test("only the latest launch counts unless asked for all", () => {
	assert.equal(trackerFires(records).get("ENG-1").length, 1);
	assert.equal(trackerFires(records, { allSessions: true }).get("ENG-1").length, 2);
	assert.equal(trackerFires(records).has("hello"), false);
});

test("trms_id is found at any depth", () => {
	assert.deepEqual(trmsIdsIn({ payload: { trms_id: "A", items: [{ trms_id: 7 }] } }), ["A", "7"]);
});

test("items[] fans out so one bad item is caught", () => {
	assert.deepEqual(valuesAt({ items: [{ item_id: "1" }, { item_id: "" }] }, "items[].item_id"), ["1", ""]);
	assert.deepEqual(valuesAt({}, "items[].item_id"), []);
});

test("contract: wrong event, empty and missing paths, expected values", () => {
	const [hit] = trackerFires(records).get("ENG-1");
	const problems = contractProblems(hit, { event: "click", required: ["items[].item_id", "cp1"], expect: { origin_screen: "pdp" } });
	assert.deepEqual(problems, ["event is `view`, expected `click`", "`items[].item_id` is empty", "missing `cp1`", "`origin_screen` is `home`, expected `pdp`"]);
});

test("summary: expected order, missing, unexpected, rejected fires", () => {
	const summary = trackerSummary(trackerFires(records), { ids: ["ENG-2", "ENG-9"] });
	assert.deepEqual(summary.rows.map((row) => [row.id, row.count, row.rejected]), [["ENG-2", 1, 1], ["ENG-9", 0, 0]]);
	assert.deepEqual(summary.missing, ["ENG-9"]);
	assert.deepEqual(summary.unexpected, ["ENG-1"]);
});

test("no ids: everything that fired, sorted", () => {
	assert.deepEqual(trackerSummary(trackerFires(records)).rows.map((row) => row.id), ["ENG-1", "ENG-2"]);
});

test("detail is newest first with a pretty payload", () => {
	const detail = trackerDetail(trackerFires(records, { allSessions: true }), "ENG-1");
	assert.deepEqual(detail.fires.map((one) => one.exchangeId), ["b", "a"]);
	assert.match(detail.fires[0].payload, /\n {2}"payload"/);
});

test("markdown has the DA table, not-fired rows and the unexpected list", () => {
	const markdown = trackerMarkdown(trackerFires(records), { ids: ["ENG-1", "ENG-9"], contracts: { "ENG-1": { required: ["cp1"] } } });
	assert.match(markdown, /1 of 2 trackers fired\. Not seen: `ENG-9` Fired with payload problems: `ENG-1`/);
	assert.match(markdown, /\*\*Not fired in this session\*\*/);
	assert.match(markdown, /\*\*Need fix\*\*<br>missing `cp1`/);
	assert.match(markdown, /## Fired but not on the list/);
	assert.match(markdown, /Validated in \*\*9\.1\*\*/);
});

test("a /track-batch body is one fire per event, each with its own event and screen", () => {
	const inner = (trms_id, event) => ({ event, payload: { app_version: "14.9", payload: { trms_id, event, origin_screen: "retail-home" } } });
	const batch = { sessionID: "s", recordedAt: "2026-10-16T07:00:00Z", exchange: {
		id: "batch", endpointKey: "POST /track-batch", request: { body: encode({ events: [inner("A-1", "view_item_list"), { event: "bwa", payload: { x: 1 } }, inner("B-2", "select_promotion")] }) },
		response: { statusCode: 200 },
	} };
	const fires = trackerFires([batch]);
	assert.deepEqual([...fires.keys()], ["A-1", "B-2"]);
	assert.equal(fires.get("B-2")[0].event, "select_promotion");
	assert.equal(fires.get("A-1")[0].originScreen, "retail-home");
	assert.match(trackerMarkdown(fires, { ids: ["A-1"] }), /Validated in \*\*14\.9\*\*/);
});
