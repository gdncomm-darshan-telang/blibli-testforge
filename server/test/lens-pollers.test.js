// D-130: which app is live, and commands reaching only the test simulator's app.
import { test } from "node:test";
import assert from "node:assert/strict";
import { pollHealth } from "../lib/lens-pollers.js";
import { queue } from "../lib/control-queue.js";

const now = 1_000_000;
const poll = (device, msAgo) => ({ device, bundle: "com.blibli.mobile", pid: "1", at: now - msAgo });

test("the test simulator's own poll is live and identified; others are listed apart", () => {
	const health = pollHealth([poll("QA", 800), poll("OTHER", 300)], { testUdid: "QA", now });
	assert.equal(health.isAppPolling, true);
	assert.equal(health.isIdentified, true);
	assert.equal(health.pollingDevice, "QA");
	assert.equal(health.lastPollMsAgo, 800);
	assert.deepEqual(health.otherDevices.map((entry) => entry.device), ["OTHER"]);
});

test("only another simulator polling is not live for the test simulator", () => {
	const health = pollHealth([poll("OTHER", 300)], { testUdid: "QA", now });
	assert.equal(health.isAppPolling, false);
	assert.deepEqual(health.otherDevices.map((entry) => entry.device), ["OTHER"]);
});

test("an older build polls anonymously: live, but not identified", () => {
	const health = pollHealth([poll(null, 300)], { testUdid: "QA", now });
	assert.equal(health.isAppPolling, true);
	assert.equal(health.isIdentified, false);
});

test("stale polls are not live", () => {
	assert.equal(pollHealth([poll("QA", 9_000)], { testUdid: "QA", now }).isAppPolling, false);
});

test("a targeted command goes only to its simulator; an anonymous poller gets it only while the target is silent", () => {
	queue.drain();
	const forQa = queue.enqueue({ kind: "state", device: "QA" });
	const untargeted = queue.enqueue({ kind: "state" });
	assert.deepEqual(queue.drain({ device: "OTHER" }).map((command) => command.id), [untargeted]);
	assert.deepEqual(queue.drain({ device: "QA" }).map((command) => command.id), [forQa]);
	const raced = queue.enqueue({ kind: "state", device: "QA" });
	assert.deepEqual(queue.drain({}), [], "an anonymous build must not take a command while its target polls");
	assert.deepEqual(queue.drain({ device: "QA" }).map((command) => command.id), [raced]);
	assert.deepEqual(queue.recentPollers.map((entry) => entry.device).sort(), ["OTHER", "QA", null].sort());
});

test("a withdrawn command is never delivered", () => {
	queue.drain();
	const id = queue.enqueue({ kind: "state", device: "QA" });
	assert.equal(queue.withdraw(id), true);
	assert.deepEqual(queue.drain({ device: "QA" }), []);
});

test("an anonymous older build elsewhere is listed as another app once the test simulator's own app is live", () => {
	const health = pollHealth([poll("QA", 500), poll(null, 400)], { testUdid: "QA", now });
	assert.equal(health.isIdentified, true);
	assert.deepEqual(health.otherDevices.map((entry) => entry.device), [null]);
});
