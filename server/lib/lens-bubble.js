// D-126 (phase C of docs/networklens-console.md): the NetworkLens bubble parks over the status bar before a test, where
// no test ever taps. Its default spot (right edge, 40 % down) covered Flash Sale's carousel arrow and blocked SF-024.
// NetworkLens stores the position as a fraction of the screen and clamps the bubble fully on screen, so "x 12 %, y 0"
// means "top-left, inside the status bar" on any phone. It reads the position at launch, from the app's own settings
// (`lib/app-defaults.js`, D-127).
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { appPreferencesDomain } from "./app-defaults.js";

const run = promisify(execFile);

export const BUBBLE_X_KEY = "com.networklens.bubble.x";
export const BUBBLE_Y_KEY = "com.networklens.bubble.y";
export const PARKED = { x: 0.12, y: 0 };
/** Stored as a 32-bit float, so 0.12 reads back as 0.119999997. */
const POSITION_TOLERANCE = 0.001;

/**
 * Parks the bubble on `udid`. Resolves to "already" (nothing to do), "parked" (written; a running app was stopped for it
 * and started again) or "failed". The app is stopped first: a running app writes its in-memory position back.
 */
export async function parkLensBubble({ udid, bundleId, exec = run, wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms)) }) {
	if (!udid || !bundleId || !/^[\w.-]+$/.test(bundleId)) return "failed";
	try {
		const plist = await appPreferencesDomain({ udid, bundleId, exec });
		const defaults = (args) => exec("xcrun", ["simctl", "spawn", udid, "defaults", ...args], { timeout: 15_000 });
		const read = async (key) => Number.parseFloat((await defaults(["read", plist, key]).catch(() => ({ stdout: "" }))).stdout);
		const isNear = (value, target) => Math.abs(value - target) < POSITION_TOLERANCE;
		const isParked = isNear(await read(BUBBLE_X_KEY), PARKED.x) && isNear(await read(BUBBLE_Y_KEY), PARKED.y);
		if (isParked) return "already";
		const { stdout: services } = await exec("xcrun", ["simctl", "spawn", udid, "launchctl", "list"], { timeout: 15_000 }).catch(() => ({ stdout: "" }));
		const wasRunning = services.includes(bundleId);
		if (wasRunning) {
			await exec("xcrun", ["simctl", "terminate", udid, bundleId], { timeout: 20_000 }).catch(() => null);
			await wait(1_000);
		}
		for (const [key, value] of [[BUBBLE_X_KEY, PARKED.x], [BUBBLE_Y_KEY, PARKED.y]]) {
			await defaults(["write", plist, key, "-float", String(value)]);
		}
		if (wasRunning) await exec("xcrun", ["simctl", "launch", udid, bundleId], { timeout: 30_000 });
		return "parked";
	} catch {
		return "failed";
	}
}
