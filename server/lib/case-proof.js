// What proof each case has in the active test batch folder (D-182), for the Tests rows' indicators.
// Proof lands in `<batch folder>/<case id>/` (Claude runs, D-109) or `<batch folder>/<prefix>-0<id>[-suffix]/`
// (replays filed under the macro's case label, e.g. MT-021, MT-025-a2). Demos and failure shots are not proof.
import { readdir, stat } from "node:fs/promises";
import { join } from "node:path";
import { isProbeShot } from "./results.js";

const IMAGE = /\.(png|jpe?g)$/i;
const VIDEO = /\.(mov|mp4)$/i;
const SKIPPED_FOLDERS = new Set(["demos", "failures"]);

/** The case id a proof folder belongs to: the folder name itself, or its number after a prefix ("MT-021" → "21"). */
export function caseIdForFolder(name, caseIds) {
	if (caseIds.has(name)) return name;
	const number = /^[A-Za-z]+-0*(\d+)(?:-.*)?$/.exec(name)?.[1];
	return number && caseIds.has(number) ? number : null;
}

/** `{ [caseId]: {screenshots, videos} }` counted from the folder; cases without proof are left out. */
export async function caseProof(folder, caseIds) {
	const ids = new Set(caseIds.map(String));
	const proof = {};
	if (!folder) return proof;
	const entries = await readdir(folder, { withFileTypes: true }).catch(() => []);
	for (const entry of entries) {
		if (!entry.isDirectory() || SKIPPED_FOLDERS.has(entry.name)) continue;
		const caseId = caseIdForFolder(entry.name, ids);
		if (!caseId) continue;
		const files = (await readdir(join(folder, entry.name)).catch(() => [])).filter((name) => !isProbeShot(name));
		const counts = proof[caseId] ?? { screenshots: 0, videos: 0 };
		counts.screenshots += files.filter((name) => IMAGE.test(name)).length;
		counts.videos += files.filter((name) => VIDEO.test(name)).length;
		proof[caseId] = counts;
	}
	return Object.fromEntries(Object.entries(proof).filter(([, counts]) => counts.screenshots || counts.videos));
}

/**
 * D-183: one case's proof files for the Tests media panel, oldest first (the order the run took them):
 * `[{path, kind: "image"|"video", modifiedAt}]`.
 */
export async function caseProofFiles(folder, caseId) {
	if (!folder) return [];
	const ids = new Set([String(caseId)]);
	const files = [];
	for (const entry of await readdir(folder, { withFileTypes: true }).catch(() => [])) {
		if (!entry.isDirectory() || SKIPPED_FOLDERS.has(entry.name) || !caseIdForFolder(entry.name, ids)) continue;
		for (const name of await readdir(join(folder, entry.name)).catch(() => [])) {
			const kind = IMAGE.test(name) ? "image" : VIDEO.test(name) ? "video" : null;
			if (!kind || isProbeShot(name)) continue;
			const path = join(folder, entry.name, name);
			const info = await stat(path).catch(() => null);
			if (info) files.push({ path, kind, modifiedAt: info.mtime.toISOString() });
		}
	}
	return files.sort((first, second) => first.modifiedAt.localeCompare(second.modifiedAt) || first.path.localeCompare(second.path));
}
