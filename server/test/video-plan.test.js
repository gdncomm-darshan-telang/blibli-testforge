// Video proof plan (D-113): film only what a screenshot can't prove, and only the case's own behaviour.
import { test } from "node:test";
import assert from "node:assert/strict";
import { needsVideo, planVideo, videoGuidance, videoWindow, MAX_VIDEO_SECONDS, HARD_STOP_SECONDS } from "../lib/video-plan.js";

const routine = (step) => ({ ...step, from: "rt_open_home" });

test("a static result needs no video", () => {
	const need = needsVideo({ scenario: "Show the Flash Sale title", expected: "Title reads Flash Sale" });
	assert.equal(need.needed, false);
	assert.equal(planVideo({ testCase: { scenario: "Show the title" }, steps: [{ do: "tap" }] }).needed, false);
	assert.match(videoGuidance({ scenario: "Show the title" }), /not needed/);
});

test("motion words need a video; launch words film from the start", () => {
	assert.equal(needsVideo({ expected: "The countdown ticks every second" }).needed, true);
	assert.equal(needsVideo({ expected: "The countdown ticks" }).fromLaunch, false);
	assert.equal(needsVideo({ steps: "Open the app from the home page", expected: "Banner animates" }).fromLaunch, true);
});

test("filming starts at the check just before the case's own action and stops after the last check", () => {
	const steps = [
		routine({ do: "tap" }),
		routine({ do: "waitFor", timeout: 5 }),
		{ do: "assert" },
		{ do: "swipe" },
		{ do: "assert" },
		{ do: "screenshot" },
		{ do: "tap" },
	];
	const plan = planVideo({ testCase: { expected: "Swipe down leaves the sheet open" }, steps });
	assert.deepEqual([plan.startIndex, plan.stopIndex, plan.maxSeconds], [2, 5, MAX_VIDEO_SECONDS]);
});

test("routine steps are never the behaviour; no own action means no video", () => {
	const plan = planVideo({ testCase: { expected: "Countdown ticks" }, steps: [routine({ do: "tap" }), { do: "assert" }] });
	assert.equal(plan.needed, false);
});

test("a long wait is a transition worth filming", () => {
	const steps = [routine({ do: "tap" }), { do: "assert" }, { do: "waitFor", timeout: 90 }, { do: "assert" }];
	const plan = planVideo({ testCase: { expected: "Sheet appears automatically when the timer ends" }, steps });
	assert.deepEqual([plan.startIndex, plan.stopIndex], [1, 3]);
});

function fakeRecorder() {
	const calls = { starts: 0, stops: 0 };
	return { calls, start: async () => (calls.starts++, { stop: async () => (calls.stops++, "/proof/SF-001.mp4") }) };
}

test("the window starts at startIndex, stops after stopIndex, once", async () => {
	const recorder = fakeRecorder();
	const window = videoWindow({ startIndex: 2, stopIndex: 3, maxSeconds: 60 }, { start: recorder.start, setTimer: () => 1, clearTimer: () => {} });
	await window.onStepStart({ index: 1 });
	assert.equal(recorder.calls.starts, 0);
	await window.onStepStart({ index: 2 });
	await window.onStep({ index: 2 });
	assert.equal(recorder.calls.stops, 0);
	await window.onStep({ index: 3 });
	await window.onStepStart({ index: 2, attempt: 2 });
	assert.equal(await window.stop(), "/proof/SF-001.mp4");
	assert.deepEqual(recorder.calls, { starts: 1, stops: 1 });
});

test("a long window keeps its end: trimmed to the last maxSeconds; the safety stop fires at HARD_STOP_SECONDS", async () => {
	const recorder = fakeRecorder();
	let fire;
	let clock = 0;
	const trims = [];
	const window = videoWindow({ startIndex: 0, stopIndex: 9, maxSeconds: 60 }, {
		start: recorder.start, now: () => clock, trim: async (path, seconds) => (trims.push(seconds), path),
		setTimer: (fn, ms) => ((fire = fn), assert.equal(ms, HARD_STOP_SECONDS * 1000)), clearTimer: () => {},
	});
	await window.onStepStart({ index: 0 });
	clock = 96_000;
	fire();
	assert.equal(await window.stop(), "/proof/SF-001.mp4");
	assert.deepEqual([recorder.calls.stops, trims], [1, [60]]);
	const short = videoWindow({ startIndex: 0, stopIndex: 0, maxSeconds: 60 }, { start: fakeRecorder().start, now: () => 0, trim: async () => assert.fail("no trim under the cap") });
	await short.onStepStart({ index: 0 });
	await short.onStep({ index: 0 });
	const unused = videoWindow({ startIndex: 5, stopIndex: 6, maxSeconds: 60 }, { start: recorder.start });
	assert.equal(await unused.stop(), null);
});
