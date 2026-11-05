import { test } from "node:test";
import assert from "node:assert/strict";
import { planBatch } from "../lib/batch-plan.js";

const macros = {
	m1: { requires: { environment: "uatb" } },
	m2: { requires: { environment: "prod" } },
	m3: { requires: { environment: "uatb", session: "loggedIn" } },
	m4: { requires: { environment: "prod" }, steps: [{ do: "manual" }] },
};
const items = [
	{ caseId: "1", mode: "replay", macroId: "m1" },
	{ caseId: "2", mode: "replay", macroId: "m2" },
	{ caseId: "9", mode: "claude" },
	{ caseId: "3", mode: "replay", macroId: "m3" },
	{ caseId: "4", mode: "replay", macroId: "m4" },
];

test("D-191: replays group by environment (current first), Claude runs go last; one switch instead of three", () => {
	const plan = planBatch({ items, macroOf: (id) => macros[id], currentEnvironment: "prod", canRunUnattended: true });
	assert.deepEqual(plan.caseIds, ["2", "4", "1", "3", "9"]);
	assert.deepEqual(plan.environmentSwitches.map((change) => [change.label, change.beforeCase]), [["UAT B", "1"]]);
	assert.equal(plan.logins, 1);
	assert.deepEqual(plan.manualCases, ["4"]);
	assert.deepEqual(plan.stops.map((stop) => stop.id), ["manual"]);
	assert.equal(plan.isHandsFree, false);
});

test("D-191: Claude runs without unattended approval and near-limit usage are named up front", () => {
	const plan = planBatch({ items: [{ caseId: "9", mode: "claude" }], macroOf: () => null, canRunUnattended: false, usage: { percent: 91, isNearLimit: true } });
	assert.deepEqual(plan.stops.map((stop) => stop.id), ["approval", "usage"]);
	assert.equal(planBatch({ items: [items[0]], macroOf: (id) => macros[id], currentEnvironment: "uatb" }).isHandsFree, true);
});
