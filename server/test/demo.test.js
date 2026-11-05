import { test } from "node:test";
import assert from "node:assert/strict";
import { createDemoRecorder, demoNotesPrompt, parseDemoNotes } from "../lib/demo.js";

const both = (en) => ({ en, id: `${en} (id)` });

test("notes: the answer is checked for both languages; unknown step ids are dropped", () => {
	const answer = `Here: ${JSON.stringify({ title: both("Tabs"), checks: both("c"), why: both("w"), setup: both("s"), steps: { st_6: both("Tap iPhone"), st_99: both("ghost") }, mocks: { "GET /a": { "mt-anchor": both("tabs jump") } } })}`;
	const { notes, mocks } = parseDemoNotes(answer, ["st_6", "st_7"]);
	assert.deepEqual(Object.keys(notes.steps), ["st_6"]);
	assert.equal(mocks["GET /a"]["mt-anchor"].id, "tabs jump (id)");
	assert.throws(() => parseDemoNotes(JSON.stringify({ title: { en: "x" } }), []), /title/);
	const methodless = parseDemoNotes(JSON.stringify({ title: both("t"), checks: both("c"), why: both("w"), mocks: { "/a": { v: both("x") } } }), [], ["GET /a"]);
	assert.deepEqual(Object.keys(methodless.mocks), ["GET /a"]);
	assert.match(demoNotesPrompt({ testCase: null, macroName: "M", rows: [{ id: "st_1", text: "Tap" }], mocks: [] }), /Bahasa Indonesia/);
});

test("recorder: actions framed before and held; checks framed after and held; times from the recording start", async () => {
	let clock = 1000;
	const sleeps = [];
	const recorder = createDemoRecorder({
		fetchFrame: async (identifier) => ({ x: 1, y: 2, width: 3, height: identifier.length }),
		screen: { width: 428, height: 926 },
		now: () => clock,
		sleep: async (ms) => {
			sleeps.push(ms);
			clock += ms;
		},
	});
	recorder.begin();
	clock += 500;
	await recorder.onStepStart({ id: "st_6", do: "tap", identifier: "tab_2" });
	clock += 300;
	await recorder.onStep({ text: "Tap iPhone", ok: true });
	await recorder.onStepStart({ id: "st_7", do: "waitForGone", identifier: "icon" });
	clock += 800;
	await recorder.onStep({ text: "icon gone", ok: true });
	await recorder.onStepStart({ id: "st_8", do: "assert", identifier: "bar" });
	await recorder.onStep({ text: "bar there", ok: false });
	await recorder.onStepStart({ id: "st_9", do: "screenshot" });
	await recorder.onStep({ text: "shot", ok: true });
	const [tap, gone, check, shot] = recorder.events;
	assert.equal(tap.startMs, 500);
	assert.equal(tap.endMs, 500 + 1500 + 300);
	assert.equal(tap.frame.height, 5);
	assert.equal(gone.frame.height, 4);
	assert.equal(check.ok, false);
	assert.equal(check.frame.height, 3);
	assert.equal(shot.frame, null);
	assert.deepEqual(sleeps, [1500, 2500, 2500]);
	const timeline = recorder.timeline({ caseId: "18", macro: { id: "mc", name: "M" }, notes: null, mockNotes: { "GET /a": { v: both("x") } }, mocks: [{ endpoint: "GET /a", variant: "v" }], verdict: "PASS" });
	assert.equal(timeline.mocks[0].note.en, "x");
	assert.deepEqual(timeline.languages, ["en", "id"]);
});

test("live overlay: focus follows the replay; noted steps without an element still hold; routines carry no note and no pause", async () => {
	const { Narrator } = await import("../lib/narration.js");
	const narrator = new Narrator({ now: () => 0 });
	narrator.begin("job", { caseId: "18", title: "M" });
	narrator.explain("job", { notes: { title: both("Tabs"), steps: { st_1: both("Open the page"), st_6: both("Tap iPhone") } }, screen: { width: 428, height: 926 } });
	assert.equal(narrator.view().runs[0].explain.phase, "intro");
	const sleeps = [];
	const recorder = createDemoRecorder({
		fetchFrame: async () => ({ x: 1, y: 2, width: 3, height: 4 }),
		screen: null,
		sleep: async (ms) => sleeps.push(ms),
		notedStepIds: new Set(["st_1", "st_6"]),
		onFocus: (focus) => narrator.explainFocus("job", focus),
	});
	recorder.begin();
	await recorder.onStepStart({ id: "st_1", do: "relaunch", from: "routine" });
	assert.equal(narrator.view().runs[0].explain.phase, "intro");
	await recorder.onStep({ text: "Relaunch", ok: true });
	await recorder.onStepStart({ id: "st_1", do: "openDeeplink", text: "Open link" });
	assert.equal(narrator.view().runs[0].explain.focus.note.en, "Open the page");
	await recorder.onStep({ text: "Open link", ok: true });
	await recorder.onStepStart({ id: "st_6", do: "tap", identifier: "tab", from: "routine" });
	assert.equal(narrator.view().runs[0].explain.focus.note, null);
	await recorder.onStep({ text: "Tap", ok: true });
	await recorder.onStepStart({ id: "st_8", do: "assert", identifier: "bar" });
	assert.equal(narrator.view().runs[0].explain.focus.style, "checking");
	await recorder.onStep({ text: "bar there", ok: true });
	assert.equal(narrator.view().runs[0].explain.focus.style, "passed");
	// The routine's tap neither points nor pauses: only the opened page and the check hold.
	assert.deepEqual(sleeps, [1500, 2500]);
	narrator.end("job", "PASS");
	assert.equal(narrator.view().runs[0].explain.phase, "result");
});

test("busy banner: setup and loading steps say what the phone is doing; a plain tap clears it", async () => {
	const { Narrator, busyMessage } = await import("../lib/narration.js");
	assert.equal(busyMessage({ do: "tap", from: "mc_home", routineName: "Open Home" }), "Getting the app ready — Open Home");
	assert.equal(busyMessage({ do: "waitFor", text: "Wait for “Microsite tabbing container” (up to 30 s)" }), "Waiting for “Microsite tabbing container” to load");
	assert.equal(busyMessage({ do: "tap", text: "Tap “Tab 2”" }), null);
	const narrator = new Narrator({ now: () => 0 });
	narrator.begin("job", { title: "M" });
	narrator.busy("job", "Getting the test runner ready");
	assert.equal(narrator.view().runs[0].busy.message, "Getting the test runner ready");
	narrator.stepStarted("job", { index: 0, do: "relaunch", text: "Relaunch the app" });
	assert.equal(narrator.view().runs[0].busy.message, "Relaunching the app");
	narrator.stepStarted("job", { index: 1, do: "tap", text: "Tap “Tab 2”" });
	assert.equal(narrator.view().runs[0].busy, null);
	narrator.busy("job", "x");
	narrator.end("job", "PASS");
	assert.equal(narrator.view().runs[0].busy, null);
});
