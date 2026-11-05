import { test } from "node:test";
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { PassThrough } from "node:stream";
import { applyScanEvent, emptyScan, ScanSession } from "../lib/scan-session.js";

test("screen events become the live view; marks group by name (D-086)", () => {
	let state = { ...emptyScan(), isActive: true };
	state = applyScanEvent(state, { event: "screen", at: "t1", elementCount: 185, identifierCount: 13, identifiers: ["A", "B"], truncated: true, distinctSeen: 1 });
	assert.deepEqual(state.current, { changedAt: "t1", elementCount: 185, identifierCount: 13, identifiers: ["A", "B"], isTruncated: true, distinctSeen: 1 });
	state = applyScanEvent(state, { event: "mark", name: "Home", variant: 1, at: "t2", elementCount: 185, identifierCount: 13, merged: 0, complete: false });
	state = applyScanEvent(state, { event: "mark", name: "Home", variant: 2, at: "t3", elementCount: 90, identifierCount: 9, merged: 1, complete: true });
	state = applyScanEvent(state, { event: "mark", name: "Cart", variant: 1, at: "t4", elementCount: 40, identifierCount: 5, complete: true });
	assert.deepEqual(state.screens.map((screen) => [screen.name, screen.variants.length]), [["Home", 2], ["Cart", 1]]);
	assert.equal(state.screens[0].variants[1].merged, 1);
});

test("poll errors show until the poll recovers; failed marks explain why", () => {
	let state = applyScanEvent(emptyScan(), { event: "pollError", error: "ConnectionRefused" });
	assert.equal(state.pollError, "ConnectionRefused");
	state = applyScanEvent(state, { event: "pollRecovered" });
	assert.equal(state.pollError, null);
	state = applyScanEvent(state, { event: "markFailed", name: "Cart", error: "empty response" });
	assert.match(state.message, /Cart/);
	assert.equal(applyScanEvent(state, { event: "skip", skipped: 3 }).skipped, 3);
});

test("the session pipes commands to the script and ends when it exits", async () => {
	const stdin = new PassThrough();
	const written = [];
	stdin.on("data", (chunk) => written.push(chunk.toString()));
	const child = Object.assign(new EventEmitter(), { stdin, stdout: new PassThrough(), stderr: new PassThrough() });
	const calls = [];
	const session = new ScanSession({
		scriptPath: "/plugin/scan_mode.py",
		outDir: await mkdtemp(join(tmpdir(), "scan-")),
		spawn: (command, args) => {
			calls.push([command, ...args]);
			return child;
		},
		now: () => new Date("2026-10-14T02:00:00Z"),
	});
	session.start();
	assert.ok(calls[0].includes("--events"));
	assert.throws(() => session.start(), /already running/);
	child.stdout.write('EVENT {"event":"screen","at":"t","elementCount":12,"identifiers":[]}\nplain line\n');
	await new Promise((resolve) => setImmediate(resolve));
	assert.equal(session.view().current.elementCount, 12);
	assert.deepEqual(session.view().lines, ["plain line"]);
	session.command("mark", "  Cart   empty ");
	session.command("stop");
	await new Promise((resolve) => setImmediate(resolve));
	assert.deepEqual(written.join(""), "mark Cart empty\nstop\n");
	assert.equal(session.view().isStopping, true);
	child.emit("exit", 0);
	assert.equal(session.isActive, false);
	assert.equal(session.view().fatal, null);
	assert.throws(() => session.command("skip"), /no scan/);
});

test("a script that exits with an error reports its last line", async () => {
	const child = Object.assign(new EventEmitter(), { stdin: new PassThrough(), stdout: new PassThrough(), stderr: new PassThrough() });
	const session = new ScanSession({ scriptPath: "/x.py", outDir: await mkdtemp(join(tmpdir(), "scan-")), spawn: () => child });
	session.start();
	child.stderr.write("no tree from the driver (empty response). Is the harness collecting?\n");
	await new Promise((resolve) => setImmediate(resolve));
	child.emit("exit", 1);
	assert.match(session.view().fatal, /harness/);
});
