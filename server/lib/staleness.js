// F1 (D-188): a result goes stale when a newer build changes the app code its case covers. A stale case
// replays from its recording without Claude; only a replay that fails goes to Claude.
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

const APP_ROOT = "BlibliMobile-iOS/BlibliMobile-iOS/";

/** Changing any of these can break every case, whatever it covers. */
export const SHARED_INPUTS = ["BlibliMobile-iOS/Podfile.lock", "BlibliMobile-iOS/BlibliMobile-iOS.xcworkspace/xcshareddata/swiftpm/Package.resolved"];

/** Macro folder (`<Module>/<Submodule>` under the UI test root, the PR Label Taxonomy) → app code it tests. */
const MODULE_CODE = {
	"Engagement/Promo": ["CustomerExperience/Engagement/Promotions"],
	"Engagement/FlashSale": ["CustomerExperience/Engagement/FlashSale", "CustomerExperience/Engagement/FlashsaleRevamp-2026"],
	"Engagement/Home": ["CustomerExperience/Engagement/Home", "CustomerExperience/Engagement/HomeScreen"],
	"Authentication/*": ["Authentication"],
	"Enticement/AboutBlibli": ["Activation/Enticement/AboutBlibli"],
	"SplashScreen/*": ["SplashScreen"],
	"PLP/autocomplete": ["Discovery/Search", "SearchAutocomplete"],
};

/** Repo-relative folders a macro covers: its own `covers`, else its module's code; null when unknown. */
export function coverageOf(macro) {
	if (Array.isArray(macro?.covers) && macro.covers.length) return macro.covers;
	const match = String(macro?.path ?? "").match(/(?:^|\/)([^/]+)\/([^/]+)\/macros\/[^/]+$/);
	if (!match) return null;
	const [, module, submodule] = match;
	const folders = MODULE_CODE[`${module}/${submodule}`] ?? MODULE_CODE[`${module}/*`];
	return folders ? folders.map((folder) => APP_ROOT + folder) : null;
}

const isUnder = (file, folder) => file === folder || file.startsWith(folder.endsWith("/") ? folder : `${folder}/`);

/** App code only: docs, tooling and the UI test target never change what a build does. */
export const isAppCode = (file) => file.startsWith(APP_ROOT) || SHARED_INPUTS.includes(file);

/**
 * Why a case's last result no longer speaks for the build under test, or null when it still does.
 * `changed` is the app-code files that differ between the two builds, null when they can't be compared.
 */
export function staleReason({ runBuild, currentBuild, changed, covers }) {
	if (!runBuild?.builtFrom || !currentBuild?.builtFrom || runBuild.builtFrom === currentBuild.builtFrom) return null;
	if (runBuild.buildInputId && runBuild.buildInputId === currentBuild.buildInputId) return null;
	if (changed === null) return { reason: `ran on ${runBuild.builtFrom}; can't compare it with ${currentBuild.builtFrom}`, files: [] };
	const shared = changed.filter((file) => SHARED_INPUTS.includes(file));
	if (shared.length) return { reason: "dependencies changed since it ran", files: shared };
	if (!covers) return changed.length ? { reason: "app code changed since it ran (coverage unknown)", files: changed.slice(0, 20) } : null;
	const hits = changed.filter((file) => covers.some((folder) => isUnder(file, folder)));
	return hits.length ? { reason: `${hits.length} covered file${hits.length === 1 ? "" : "s"} changed since it ran`, files: hits.slice(0, 20) } : null;
}

/** Content hashes of a snapshot's locally changed files, so two snapshots on one commit can be compared. */
export async function localHashes(copyPath, changedFiles = []) {
	const hashes = {};
	for (const file of changedFiles.filter(isAppCode)) {
		const content = await readFile(join(copyPath, file)).catch(() => null);
		hashes[file] = content ? createHash("sha1").update(content).digest("hex").slice(0, 12) : "deleted";
	}
	return hashes;
}

/**
 * App-code files that differ between two snapshots: the commit diff plus local edits on either side.
 * `diffNames(fromSha, toSha)` lists committed changes; snapshots are `{ sha, local: {file: hash} }`.
 */
export async function changedBetween(from, to, diffNames) {
	if (!from?.sha || !to?.sha) return null;
	const committed = from.sha === to.sha ? [] : await diffNames(from.sha, to.sha).catch(() => null);
	if (committed === null) return null;
	const files = new Set(committed.filter(isAppCode));
	const fromLocal = from.local ?? {};
	const toLocal = to.local ?? {};
	for (const file of new Set([...Object.keys(fromLocal), ...Object.keys(toLocal)])) {
		if (fromLocal[file] !== toLocal[file]) files.add(file);
	}
	return [...files].sort();
}
