// D-127: the app's own settings on a simulator — read, write and delete in the plist the app actually reads.
// `simctl spawn <udid> defaults … <bundle id>` goes to the simulator's shared domain, which a sandboxed app never reads
// (a value written there "works" only when the app's own default happens to match). Editing the file from the Mac is
// ignored too: the simulator's preferences service keeps the domain cached. What works is that service, by file path:
// `simctl spawn <udid> defaults <verb> <data container>/Library/Preferences/<bundle id> …` (proven in D-126).
import { execFile } from "node:child_process";
import { join } from "node:path";
import { promisify } from "node:util";

const run = promisify(execFile);
const SAFE_NAME = /^[\w.-]+$/;

export const DEFAULT_BUNDLE_ID = process.env.NETWORKLENS_BUNDLE_ID || "com.blibli.mobile";

/** `<data container>/Library/Preferences/<bundle id>` — the domain `defaults` takes, without `.plist`. */
export async function appPreferencesDomain({ udid, bundleId = DEFAULT_BUNDLE_ID, exec = run }) {
	if (!udid || !SAFE_NAME.test(bundleId)) throw new Error("bad device or bundle id");
	const { stdout } = await exec("xcrun", ["simctl", "get_app_container", udid, bundleId, "data"], { timeout: 20_000 });
	return join(stdout.trim(), "Library", "Preferences", bundleId);
}

const defaults = (udid, args, exec) => exec("xcrun", ["simctl", "spawn", udid, "defaults", ...args], { timeout: 15_000 });

/** The value as `defaults read` prints it (booleans "1"/"0"); null when the key or the app is absent. */
export async function readAppDefault({ udid, bundleId = DEFAULT_BUNDLE_ID, key, exec = run }) {
	try {
		const domain = await appPreferencesDomain({ udid, bundleId, exec });
		const { stdout } = await defaults(udid, ["read", domain, key], exec);
		return stdout.trim();
	} catch {
		return null;
	}
}

/** `type` is a `defaults write` flag without the dash: bool, int, float or string. */
export async function writeAppDefault({ udid, bundleId = DEFAULT_BUNDLE_ID, key, type, value, exec = run }) {
	if (!["bool", "int", "float", "string"].includes(type)) throw new Error(`unsupported defaults type ${type}`);
	const domain = await appPreferencesDomain({ udid, bundleId, exec });
	await defaults(udid, ["write", domain, key, `-${type}`, String(value)], exec);
}

/** A missing key already is the wanted state, so that is not an error. */
export async function deleteAppDefault({ udid, bundleId = DEFAULT_BUNDLE_ID, key, exec = run }) {
	const domain = await appPreferencesDomain({ udid, bundleId, exec });
	await defaults(udid, ["delete", domain, key], exec).catch((error) => {
		if (!/does not exist|not found/i.test(`${error.stderr ?? ""}${error.stdout ?? ""}${error.message}`)) throw error;
	});
}
