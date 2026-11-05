// D-156: Claude Code's own tools (the `networklens` + `qa-driver` MCP servers) need personal,
// per-Mac values — this developer's project path, QA simulator UDID, proof folder — to target the
// right device when used directly in a Claude Code session, outside the dashboard (which already
// resolves all of this per request instead, D-032, so it never needed these). They belong in
// `.claude/settings.local.json`'s `env` block, which every developer keeps out of git — never in
// the tracked `.claude/settings.json`, which has no personal values in it. This module works out
// what this Mac's values should be (nothing for the developer to type in) and merges them into
// that file, so a fresh clone doesn't need hand-edited JSON before Claude's own tools work.
import { readFile, rename, writeFile } from "node:fs/promises";
import { DEFAULT_BUNDLE_ID } from "./app-defaults.js";
import { findQaSimulator } from "./qa-simulator.js";

export const LOCAL_ENV_KEYS = [
	"QA_BUNDLE_ID",
	"NETWORKLENS_BUNDLE_ID",
	"QA_PROJECT_DIR",
	"QA_UITEST_TARGET",
	"QA_DATA_PLANE",
	"QA_MEDIA_ROOT",
	"QA_DEVICE_UDID",
];

/** The real filesystem, for the server. Tests inject a fake `deps` instead. */
export function realDeps() {
	return { readFile, writeFile, rename };
}

/** What this Mac's env values should be, worked out from what the dashboard server already knows. */
export async function detectLocalEnv({
	projectDir, mediaRoot, uitestTarget = "BlibliMobile_XCUITest", bundleId = DEFAULT_BUNDLE_ID, findQaSim = findQaSimulator,
} = {}) {
	const qa = await findQaSim().catch(() => null);
	return {
		QA_BUNDLE_ID: bundleId,
		NETWORKLENS_BUNDLE_ID: bundleId,
		QA_PROJECT_DIR: projectDir ?? null,
		QA_UITEST_TARGET: uitestTarget,
		QA_DATA_PLANE: "simctl",
		QA_MEDIA_ROOT: mediaRoot ?? null,
		QA_DEVICE_UDID: qa?.udid ?? null,
	};
}

/** Keys `expected` has an opinion on (non-null) that `actual` is missing or disagrees with. */
export function diffLocalEnv(expected, actual = {}) {
	return LOCAL_ENV_KEYS.filter((key) => expected[key] != null && expected[key] !== actual[key]);
}

async function readJson(path, { readFile: read }) {
	try {
		return JSON.parse(await read(path, "utf8"));
	} catch (error) {
		if (error.code === "ENOENT") return null;
		throw error;
	}
}

/** The `env` block of `path` — `{}` once nothing has been written there yet. What `diffLocalEnv`
 *  compares the detected values against. */
export async function readLocalEnv(path, deps) {
	const settings = await readJson(path, deps);
	return settings?.env ?? {};
}

/**
 * Merges `env` into `path`'s settings, seeding from `examplePath`'s generic baseline the first
 * time this Mac writes it (the permissions/hooks/MCP toggles every developer shares); every key
 * already in `path` passes through untouched except `env`, which this merges rather than replaces.
 * Atomic write (temp file + rename), same idiom as `exportRules` in `lib/mock-pack.js`. Only
 * `LOCAL_ENV_KEYS` with a resolved (non-null) value are written.
 */
export async function writeLocalEnv(path, env, { examplePath = null } = {}, deps) {
	const base = (await readJson(path, deps)) ?? (examplePath ? await readJson(examplePath, deps) : null) ?? {};
	const clean = Object.fromEntries(LOCAL_ENV_KEYS.filter((key) => env[key] != null).map((key) => [key, env[key]]));
	const merged = { ...base, env: { ...base.env, ...clean } };
	const temporary = `${path}.tmp-${process.pid}`;
	await deps.writeFile(temporary, `${JSON.stringify(merged, null, 2)}\n`, "utf8");
	await deps.rename(temporary, path);
	return merged;
}
