import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { buildRecordedMacro, freeMacroName, missingIdentifierWarnings } from "../lib/recorded-macro.js";

const registry = { schemaVersion: 1, elements: { el_EXISTING01: { alias: "Akun tab", quality: "identifier", locator: { chain: [{ identifier: "TabBarAccountViewTab" }] } } } };
const gestures = [
	{ gesture: "tap", identifier: "TabBarAccountViewTab", label: "Akun", screenName: "Home", anchorIdentifier: "settingButton", nextScreenName: "Akun" },
	{ gesture: "swipeUp", identifier: "", label: "", screenName: "Akun" },
	{ gesture: "tap", identifier: "", label: "Bahasa", screenName: "Pengaturan", anchorIdentifier: "LanguageList", nextScreenName: "Bahasa" },
	{ gesture: "tap", identifier: "", label: "", screenName: "Bahasa" },
];

test("recorded gestures become identifier taps, swipes, label fallbacks and manual steps (D-171)", () => {
	const { macro, createdElements } = buildRecordedMacro({ name: "Change language", caseIds: ["15", " "], gestures }, registry);
	assert.deepEqual(macro.steps.map((step) => step.do), ["relaunch", "tap", "waitFor", "screenshot", "swipe", "tap", "waitFor", "screenshot", "manual"]);
	assert.equal(macro.steps[1].el, "el_EXISTING01", "an element already in the registry is reused");
	assert.equal(macro.steps[4].direction, "up");
	assert.deepEqual(macro.links, { testCases: ["15"] });
	assert.equal(macro.recordedBy, "scan");
	assert.equal(createdElements.length, 3, "settingButton, Bahasa label, LanguageList");
});

test("label-only elements are stored as label fallbacks; the same anchor is created once", () => {
	const { macro, registry: next } = buildRecordedMacro({ name: "x", gestures: [gestures[2], gestures[2]], startFresh: false }, registry);
	const label = next.elements[macro.steps[0].el];
	assert.equal(label.quality, "label");
	assert.deepEqual(label.locator, { fallbacks: [{ label: "Bahasa", match: "EQUALS" }] });
	assert.equal(macro.steps[0].el, macro.steps[3].el);
	assert.equal(macro.steps[1].el, macro.steps[4].el);
});

test("warnings name every tap without an accessibility ID; swipes and identifier taps are fine", () => {
	const warnings = missingIdentifierWarnings(gestures);
	assert.deepEqual(warnings.map(({ step, quality }) => ({ step, quality })), [{ step: 3, quality: "label" }, { step: 4, quality: "none" }]);
	assert.match(warnings[0].text, /“Bahasa” on Pengaturan has no accessibility ID/);
});

test("a recorded macro never overwrites an existing file", async () => {
	const folder = await mkdtemp(join(tmpdir(), "recorded-"));
	await mkdir(folder, { recursive: true });
	assert.equal(await freeMacroName("Change language", folder), "Change language");
	await writeFile(join(folder, "change-language.json"), "{}");
	assert.equal(await freeMacroName("Change language", folder), "Change language 2");
});

test("Scan's list keeps only macros recorded in Scan, newest first, with their ID coverage", async () => {
	const { recordedMacros } = await import("../lib/recorded-macro.js");
	const macros = [
		{ id: "a", name: "Old", createdAt: "2026-10-01T00:00:00Z", recordedBy: "scan", path: "M/S/macros/old.json", steps: [{ do: "relaunch" }, { do: "tap", note: "Recorded: tap — no accessibility ID, found by its text" }, { do: "manual" }] },
		{ id: "b", name: "Written by Claude", createdAt: "2026-10-05T00:00:00Z", steps: [{ do: "tap" }] },
		{ id: "c", name: "New", createdAt: "2026-10-09T00:00:00Z", recordedBy: "scan", path: "M/S/macros/new.json", links: { testCases: ["15"] }, steps: [{ do: "tap" }, { do: "swipe" }] },
	];
	const rows = recordedMacros(macros, "/root");
	assert.deepEqual(rows.map((row) => row.id), ["c", "a"]);
	assert.deepEqual(rows[0], { id: "c", name: "New", createdAt: "2026-10-09T00:00:00Z", testCases: ["15"], path: "/root/M/S/macros/new.json", gestureCount: 2, foundByText: 0, needsPerson: 0, startsFresh: false });
	assert.equal(rows[1].foundByText, 1);
	assert.equal(rows[1].needsPerson, 1);
	assert.equal(rows[1].startsFresh, true);
});

test("D-194: a tap without an identifier replays by its container and position; a system-alert tap answers the alert", () => {
	const gestures = [
		{ gesture: "tap", label: "", role: "AXButton", containerIdentifier: "MicrositeTabsBar", elementType: "button", index: 2 },
		{ gesture: "tap", label: "Allow While Using App", role: "AXButton" },
		{ gesture: "tap", label: "", role: "AXButton" },
	];
	const { macro, registry, warnings } = buildRecordedMacro({ name: "Fallbacks", gestures, startFresh: false }, { elements: {} });
	const [containerTap, alert, manual] = macro.steps;
	assert.equal(containerTap.do, "tap");
	assert.deepEqual(registry.elements[containerTap.el].locator.chain, [{ identifier: "MicrositeTabsBar" }, { type: "button", index: 2 }]);
	assert.equal(registry.elements[containerTap.el].quality, "container");
	assert.deepEqual({ do: alert.do, button: alert.button, optional: alert.optional }, { do: "alertTap", button: "Allow While Using App", optional: true });
	assert.equal(manual.do, "manual");
	assert.deepEqual(warnings.map((warning) => warning.step), [3]);
});
