import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { applyCaseEdits, createCaseEditStore, mergeCaseEdit, mergeImportedCases, separateCarriedEdits } from "../lib/case-edits.js";
import { testcaseView } from "../lib/testcase-view.js";

const documentCase = { id: "15", scenario: "URL mode: click on another tab", expected: "Selected indicator moves to the tapped tab." };
const now = new Date("2026-11-01T03:00:00Z");

test("an edit keeps only fields that differ from the document, with the document's text (D-166)", () => {
	const edit = mergeCaseEdit(documentCase, null, { expected: "Indicator stays on the original tab.", scenario: "URL mode: click on another tab" }, now);
	assert.deepEqual(edit, {
		fields: { expected: "Indicator stays on the original tab." },
		original: { expected: "Selected indicator moves to the tapped tab." },
		editedAt: "2026-11-01T03:00:00.000Z",
	});
});

test("setting a field back to the document's text drops it; nothing left removes the edit", () => {
	const edit = mergeCaseEdit(documentCase, null, { expected: "Indicator stays." }, now);
	assert.equal(mergeCaseEdit(documentCase, edit, { expected: " Selected indicator moves to the tapped tab.\n" }, now), null);
});

test("edited cases carry localEdit with the document's text; others are untouched", () => {
	const edit = mergeCaseEdit(documentCase, null, { expected: "Indicator stays." }, now);
	const [edited, plain] = applyCaseEdits([documentCase, { id: "16", scenario: "Other" }], { 15: edit });
	assert.equal(edited.expected, "Indicator stays.");
	assert.deepEqual(edited.localEdit, {
		fields: ["expected"], editedAt: "2026-11-01T03:00:00.000Z",
		original: { expected: "Selected indicator moves to the tapped tab." }, isDocumentChanged: false,
	});
	assert.equal(plain.localEdit, undefined);
});

test("flags an edit whose document text changed after it was made", () => {
	const edit = mergeCaseEdit(documentCase, null, { expected: "Indicator stays." }, now);
	const [edited] = applyCaseEdits([{ ...documentCase, expected: "Reworded by the doc owner." }], { 15: edit });
	assert.equal(edited.expected, "Indicator stays.");
	assert.equal(edited.localEdit.isDocumentChanged, true);
	assert.equal(edited.localEdit.original.expected, "Reworded by the doc owner.");
});

test("the store keeps edits per document source and survives a reload", async () => {
	const file = join(await mkdtemp(join(tmpdir(), "case-edits-")), "case-edits.json");
	const store = createCaseEditStore(file);
	await store.load();
	const edit = mergeCaseEdit(documentCase, null, { expected: "Indicator stays." }, now);
	await store.set("page-a", "15", edit);
	assert.deepEqual(store.forSource("page-b"), {});
	const reloaded = createCaseEditStore(file);
	await reloaded.load();
	assert.deepEqual(reloaded.forSource("page-a"), { 15: edit });
	await reloaded.set("page-a", "15", null);
	assert.deepEqual(JSON.parse(await readFile(file, "utf8")), {});
});

test("the testcases view sends localEdit, null when the case is unedited", () => {
	const edit = mergeCaseEdit(documentCase, null, { expected: "Indicator stays." }, now);
	const view = testcaseView({ cases: applyCaseEdits([documentCase, { id: "16", scenario: "Other" }], { 15: edit }) });
	assert.deepEqual(view.cases[0].localEdit.fields, ["expected"]);
	assert.equal(view.cases[1].localEdit, null);
});

test("a loaded bundle's edited cases go back to the document's text, with their edits to store", () => {
	const edit = mergeCaseEdit(documentCase, null, { expected: "Indicator stays." }, now);
	const [carried] = applyCaseEdits([documentCase], { 15: edit });
	const { cases, edits } = separateCarriedEdits([carried, { id: "16", scenario: "Other" }]);
	assert.deepEqual(cases[0], documentCase);
	assert.deepEqual(edits, { 15: edit });
	assert.deepEqual(applyCaseEdits(cases, edits)[0].expected, "Indicator stays.");
});

test("a bundle import adds its missing cases and keeps the loaded ones", () => {
	const loaded = [{ id: "3", scenario: "doc 3" }, { id: "18", scenario: "doc 18" }, { id: "21", scenario: "doc 21" }];
	const bundle = [{ id: "21", scenario: "bundle 21" }, { id: "22", scenario: "bundle 22" }];
	const { cases, added } = mergeImportedCases(loaded, bundle);
	assert.deepEqual(cases.map((testCase) => testCase.id), ["3", "18", "21", "22"]);
	assert.equal(cases[2].scenario, "doc 21");
	assert.deepEqual(added, ["22"]);
});
