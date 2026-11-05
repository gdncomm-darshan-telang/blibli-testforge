import { test } from "node:test";
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { StateHub } from "../lib/state-hub.js";
import { jobView, phaseOf, withBatchPhases, withTaskPhase } from "../lib/lifecycle.js";

const tick = (ms = 0) => new Promise((resolve) => setTimeout(resolve, ms));

test("R1: every status maps to one of six phases", () => {
	assert.equal(phaseOf("queued"), "waiting");
	assert.equal(phaseOf("waiting-device"), "waiting");
	assert.equal(phaseOf("running"), "working");
	assert.equal(phaseOf("done"), "done");
	assert.equal(phaseOf("error"), "failed");
	assert.equal(phaseOf("failed"), "failed");
	assert.equal(phaseOf("cancelled"), "cancelled");
	assert.equal(phaseOf("skipping"), "cancelling");
	assert.equal(phaseOf("running", { isCancelRequested: true }), "cancelling");
	assert.equal(phaseOf("done", { isCancelRequested: true }), "done");
	assert.equal(withTaskPhase({ status: "running", isCancelRequested: true }).phase, "cancelling");
	assert.equal(jobView({ id: "j", meta: {}, status: "running", isCancelled: true, lines: ["x"] }).phase, "cancelling");
	assert.equal(jobView({ id: "j", meta: {}, status: "running", lines: ["x"] }).lines, undefined);
});

test("R1: a cancelled batch is cancelling until its current case stops", () => {
	const stopping = withBatchPhases({ status: "cancelled", items: [{ status: "running" }, { status: "cancelled" }] });
	assert.equal(stopping.phase, "cancelling");
	assert.deepEqual(stopping.items.map((item) => item.phase), ["working", "cancelled"]);
	assert.equal(withBatchPhases({ status: "cancelled", items: [{ status: "cancelled" }] }).phase, "cancelled");
	assert.equal(withBatchPhases({ status: "paused", items: [] }).phase, "waiting");
	assert.equal(withBatchPhases(null), null);
});

test("R1: the hub pushes a slice only when it changed", async () => {
	const hub = new StateHub({ throttleMs: 5 });
	let value = { n: 1 };
	hub.define("a", { read: async () => value });
	const patches = [];
	const off = hub.subscribe((patch) => patches.push(patch));
	await tick(10);
	assert.equal(patches.length, 1);
	assert.deepEqual(patches[0].value, { n: 1 });
	await hub.refresh("a");
	assert.equal(patches.length, 1, "same value → no push");
	value = { n: 2 };
	hub.poke("a");
	hub.poke("a");
	await tick(20);
	assert.equal(patches.length, 2, "two pokes in one burst → one read, one push");
	assert.ok(patches[1].version > patches[0].version);
	assert.deepEqual(hub.snapshot().slices.a.value, { n: 2 });
	off();
	hub.close();
});

test("R1: probes run only while someone is connected; errors are pushed once", async () => {
	const hub = new StateHub({ throttleMs: 1 });
	let reads = 0;
	let isBroken = false;
	hub.define("probe", { everyMs: 10, read: async () => {
		reads++;
		if (isBroken) throw new Error("simulator gone");
		return "ok";
	} });
	await tick(30);
	assert.equal(reads, 0, "no page, no probe");
	const patches = [];
	const off = hub.subscribe((patch) => patches.push(patch));
	await tick(35);
	assert.ok(reads >= 2);
	isBroken = true;
	await tick(35);
	const errors = patches.filter((patch) => patch.error);
	assert.equal(errors.length, 1);
	assert.equal(errors[0].error, "simulator gone");
	assert.equal(errors[0].value, "ok", "the last good value stays");
	off();
	const after = reads;
	await tick(30);
	assert.equal(reads, after, "last page gone → probing stops");
	hub.close();
});

test("R1: watched emitters poke; pushed slices are set directly; a poke during a read is not lost", async () => {
	const hub = new StateHub({ throttleMs: 1 });
	const source = new EventEmitter();
	let value = 1;
	let release;
	hub.define("w", { read: async () => {
		const seen = value;
		if (seen === 2) await new Promise((resolve) => (release = resolve));
		return seen;
	} });
	hub.define("pushed", {});
	hub.watch("w", source);
	const patches = [];
	hub.subscribe((patch) => patches.push(patch));
	await tick(5);
	value = 2;
	source.emit("change");
	await tick(5);
	value = 3;
	source.emit("change");
	await tick(5);
	release();
	await tick(10);
	assert.deepEqual(patches.filter((patch) => patch.slice === "w").map((patch) => patch.value), [1, 2, 3]);
	hub.set("pushed", { step: 1 });
	assert.deepEqual(patches.at(-1), { slice: "pushed", value: { step: 1 }, version: patches.at(-1).version, at: patches.at(-1).at, error: null });
	hub.close();
});
