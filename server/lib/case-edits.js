// Local edits to loaded test cases (D-166). The source document (often a read-only production page) is
// never changed: edits live beside it, keyed by document source and case id, and are laid over the
// document's own text every time it is loaded, so a reload keeps them.
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname } from "node:path";

export const EDITABLE_FIELDS = ["scenario", "precondition", "steps", "expected", "api"];

const normalized = (value) => String(value ?? "").replace(/\r\n/g, "\n").trim();

/**
 * The document's cases with any local edits laid over them. An edited case carries `localEdit`:
 * the edited field names, when, the document's own text for those fields, and whether the document
 * has changed that text since the edit (so the person can check the edit still makes sense).
 */
export function applyCaseEdits(cases, editsForSource = {}) {
	return cases.map((testCase) => {
		const edit = editsForSource[testCase.id];
		if (!edit) return testCase;
		const fields = Object.keys(edit.fields).filter((field) => EDITABLE_FIELDS.includes(field));
		if (fields.length === 0) return testCase;
		const documentText = Object.fromEntries(fields.map((field) => [field, testCase[field] ?? null]));
		const isDocumentChanged = fields.some((field) => normalized(edit.original?.[field]) !== normalized(testCase[field]));
		return {
			...testCase,
			...Object.fromEntries(fields.map((field) => [field, edit.fields[field]])),
			localEdit: { fields, editedAt: edit.editedAt, original: documentText, isDocumentChanged },
		};
	});
}

/**
 * The stored edit for one case after a save: only fields that differ from the document are kept, and
 * null means nothing differs (the edit is removed). `documentCase` is the case as the document has it.
 */
export function mergeCaseEdit(documentCase, previousEdit, changes, now = new Date()) {
	const fields = { ...(previousEdit?.fields ?? {}) };
	const original = { ...(previousEdit?.original ?? {}) };
	for (const field of EDITABLE_FIELDS) {
		if (!(field in changes)) continue;
		const value = normalized(changes[field]);
		if (value === normalized(documentCase[field])) {
			delete fields[field];
			delete original[field];
		} else {
			fields[field] = value;
			original[field] = documentCase[field] ?? null;
		}
	}
	return Object.keys(fields).length ? { fields, original, editedAt: now.toISOString() } : null;
}

/**
 * Cases that arrive already edited (a run bundle carries the text that ran, with `localEdit`): the
 * document's own text back in place, and the edits to store, so the receiver sees the same marker and
 * can revert just as the sender could.
 */
export function separateCarriedEdits(cases) {
	const edits = {};
	const documentCases = cases.map((testCase) => {
		const { localEdit, ...rest } = testCase;
		if (!localEdit?.fields?.length) return rest;
		const fields = Object.fromEntries(localEdit.fields.map((field) => [field, rest[field]]));
		const original = Object.fromEntries(localEdit.fields.map((field) => [field, localEdit.original?.[field] ?? null]));
		edits[rest.id] = { fields, original, editedAt: localEdit.editedAt };
		return { ...rest, ...original };
	});
	return { cases: documentCases, edits };
}

/**
 * D-181: a bundle's cases added to the loaded document instead of replacing it. Cases already loaded keep the
 * document's text and order; the bundle's other cases follow, in the bundle's order. `added` lists their ids.
 */
export function mergeImportedCases(current, incoming) {
	const known = new Set(current.map((testCase) => String(testCase.id)));
	const extra = incoming.filter((testCase) => !known.has(String(testCase.id)));
	return { cases: [...current, ...extra], added: extra.map((testCase) => testCase.id) };
}

export function createCaseEditStore(file) {
	let edits = {};
	// Saves run one after another: a bundle load stores several edits at once, all through one temp file.
	let saving = Promise.resolve();
	const writeNow = async () => {
		await mkdir(dirname(file), { recursive: true });
		const temp = `${file}.${process.pid}.tmp`;
		await writeFile(temp, `${JSON.stringify(edits, null, 2)}\n`);
		await rename(temp, file);
	};
	const save = () => {
		saving = saving.catch(() => {}).then(writeNow);
		return saving;
	};
	return {
		async load() {
			try {
				const saved = JSON.parse(await readFile(file, "utf8"));
				edits = saved && typeof saved === "object" ? saved : {};
			} catch {
				edits = {};
			}
		},
		forSource: (source) => edits[source] ?? {},
		async set(source, caseId, edit) {
			const forSource = { ...(edits[source] ?? {}) };
			if (edit) forSource[caseId] = edit;
			else delete forSource[caseId];
			if (Object.keys(forSource).length) edits[source] = forSource;
			else delete edits[source];
			await save();
		},
	};
}
