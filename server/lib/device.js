// The booted simulator as the dashboard sees it: which device, and a one-off screen capture for
// "Ask Claude about this screen". A capture takes ~1.4 s, so it is single-flight and shared.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { deviceArg } from "./test-device.js";

const run = promisify(execFile);
const FRESH_MS = 800;

let frame = null; // { buffer, at }
let capturing = null;

export async function bootedDevice() {
	try {
		const { stdout } = await run("xcrun", ["simctl", "list", "devices", "booted", "-j"], { timeout: 10_000 });
		for (const [runtime, devices] of Object.entries(JSON.parse(stdout).devices)) {
			const device = devices.find((candidate) => candidate.state === "Booted" && candidate.udid === deviceArg()) ?? (deviceArg() === "booted" ? devices.find((candidate) => candidate.state === "Booted") : null);
			if (device) return { udid: device.udid, name: device.name, runtime: runtime.split(".").pop().replace(/-/g, " ").replace(/ (\d+) (\d+)$/, " $1.$2") };
		}
	} catch {
		// simctl missing or no Xcode — treated as no device.
	}
	return null;
}

/** Latest JPEG of the booted simulator's screen; reuses a frame younger than FRESH_MS. */
export async function captureFrame() {
	if (frame && Date.now() - frame.at < FRESH_MS) return frame;
	if (!capturing) {
		capturing = run("xcrun", ["simctl", "io", deviceArg(), "screenshot", "--type=jpeg", "-"], { encoding: "buffer", maxBuffer: 20 * 1024 * 1024, timeout: 10_000 })
			.then(({ stdout }) => {
				frame = { buffer: stdout, at: Date.now() };
				return frame;
			})
			.finally(() => {
				capturing = null;
			});
	}
	return capturing;
}

/** Attachment shape for a Claude message ("Ask Claude about this screen"). */
export async function screenshotAttachment() {
	const { buffer } = await captureFrame();
	return { base64: buffer.toString("base64"), mediaType: "image/jpeg" };
}

/** `deviceInfo` answer → `{ deviceName, udid, width, height }` in points, or null. */
export function screenOf(outcome) {
	const value = outcome?.value ?? outcome;
	const match = /^(\d+(?:\.\d+)?)x(\d+(?:\.\d+)?)$/.exec(String(value?.screenPoints ?? ""));
	if (!match || outcome?.error) return null;
	return { deviceName: value.deviceName ?? null, udid: value.udid ?? null, width: Number(match[1]), height: Number(match[2]) };
}

// The last screen size the runner reported (every readiness probe asks `deviceInfo`), so the Mac app
// can map device points onto the Simulator window without sending a command of its own.
let lastScreen = null;

export function noteDeviceInfo(outcome) {
	const screen = screenOf(outcome);
	if (screen) lastScreen = { ...screen, at: new Date().toISOString() };
	return lastScreen;
}

export function deviceScreen() {
	return lastScreen;
}
