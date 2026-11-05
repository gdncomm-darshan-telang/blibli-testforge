// D-126: the bubble is parked by writing NetworkLens's own fractional position into the app's container plist.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parkLensBubble, BUBBLE_X_KEY, BUBBLE_Y_KEY } from "../lib/lens-bubble.js";

function fakeSimulator({ stored, isRunning }) {
	const calls = [];
	const exec = async (bin, args) => {
		calls.push([bin, ...args]);
		if (args[1] === "get_app_container") return { stdout: "/data/app\n" };
		if (args[3] === "defaults" && args[4] === "read") return { stdout: `${stored[args[6]] ?? ""}` };
		if (args[3] === "launchctl") return { stdout: isRunning ? "UIKitApplication:com.blibli.mobile[1]" : "" };
		return { stdout: "" };
	};
	return { calls, exec };
}

test("writes both fractions into the app's container plist, stopping and restarting a running app", async () => {
	const simulator = fakeSimulator({ stored: { [BUBBLE_X_KEY]: 0.93, [BUBBLE_Y_KEY]: 0.48 }, isRunning: true });
	const outcome = await parkLensBubble({ udid: "QA1", bundleId: "com.blibli.mobile", exec: simulator.exec, wait: async () => {} });
	assert.equal(outcome, "parked");
	const writes = simulator.calls.filter((call) => call[4] === "defaults" && call[5] === "write").map((call) => call.slice(6));
	assert.deepEqual(writes, [
		["/data/app/Library/Preferences/com.blibli.mobile", BUBBLE_X_KEY, "-float", "0.12"],
		["/data/app/Library/Preferences/com.blibli.mobile", BUBBLE_Y_KEY, "-float", "0"],
	]);
	const order = simulator.calls.map((call) => call[2]).filter((verb) => verb === "terminate" || verb === "launch");
	assert.deepEqual(order, ["terminate", "launch"]);
});

test("an already parked bubble is left alone, and a stopped app is not started", async () => {
	const parked = fakeSimulator({ stored: { [BUBBLE_X_KEY]: 0.119999997, [BUBBLE_Y_KEY]: 0 }, isRunning: true });
	assert.equal(await parkLensBubble({ udid: "QA1", bundleId: "x", exec: parked.exec }), "already");
	assert.ok(!parked.calls.some((call) => (call[4] === "defaults" && call[5] === "write") || call[2] === "terminate"));
	const stopped = fakeSimulator({ stored: {}, isRunning: false });
	assert.equal(await parkLensBubble({ udid: "QA1", bundleId: "x", exec: stopped.exec, wait: async () => {} }), "parked");
	assert.ok(!stopped.calls.some((call) => call[2] === "launch" || call[2] === "terminate"));
});

test("no device or a failing simctl is not an error", async () => {
	assert.equal(await parkLensBubble({ udid: null, bundleId: "x" }), "failed");
	assert.equal(await parkLensBubble({ udid: "QA1", bundleId: "x", exec: async () => { throw new Error("shut down"); } }), "failed");
});
