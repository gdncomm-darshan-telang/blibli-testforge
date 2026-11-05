import { execFile } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import { androidPackage, isAndroidAppRunning, pullLensFile } from "./android.js";
const run = promisify(execFile);
const TRACE_RELATIVE_PATH = join("Library", "Application Support", "NetworkLens", "trace.ndjson");
/**
 * Where the trace is, in precedence order.
 *
 * NETWORKLENS_TRACE wins because a device trace pulled off with Xcode lands
 * wherever the person put it, and no amount of guessing finds that.
 *
 * NETWORKLENS_ANDROID_PACKAGE sits second: the pull is a subprocess and a file copy, so
 * an explicit path still short-circuits it, but naming a package is a deliberate act and
 * should beat the iOS fallbacks below. The pulled file's name encodes the device file's
 * size and mtime, so `TraceReader`'s existing mtime+size parse cache keeps working with
 * no change at all.
 */
export async function resolveTracePath() {
    const explicit = process.env.NETWORKLENS_TRACE;
    if (explicit)
        return { path: explicit, how: "NETWORKLENS_TRACE" };
    const androidPkg = androidPackage();
    if (androidPkg) {
        const pulled = await pullLensFile(androidPkg, "trace.ndjson");
        if (pulled)
            return pulled;
        // Reported rather than silently falling through to a macOS path that will not exist:
        // "no rows" with no reason is the single most confusing state this tool has.
        return {
            path: join(tmpdir(), "networklens-adb", androidPkg, "trace.ndjson"),
            how: `no trace on device for ${androidPkg} (is TraceOptions set, and has the app made a request?)`,
        };
    }
    const bundleId = process.env.NETWORKLENS_BUNDLE_ID;
    if (bundleId) {
        const container = await bootedAppContainer(bundleId);
        if (container) {
            return { path: join(container, TRACE_RELATIVE_PATH), how: `simctl container for ${bundleId}` };
        }
    }
    // A macOS host app, or the package's own tests.
    return {
        path: join(homedir(), "Library", "Application Support", "NetworkLens", "trace.ndjson"),
        how: "host Application Support",
    };
}
/**
 * Whether the app is currently running on the booted simulator.
 *
 * Matters because the app owns `session.json` while it lives: it reads the file
 * at `start()` and autosaves its in-memory state back over it on every edit. A
 * write made while it runs is overwritten within seconds, and the only symptom
 * is an empty Mocks tab — which reads as the tool being broken rather than as a
 * race that was always going to be lost.
 *
 * Unknown counts as not running: `launchctl` inside a simulator is best-effort,
 * and refusing a legitimate write because a probe failed is the worse error.
 */
export async function isAppRunning(bundleId) {
    const androidPkg = androidPackage();
    if (androidPkg)
        return isAndroidAppRunning(androidPkg);
    try {
        const { stdout } = await run("xcrun", ["simctl", "spawn", "booted", "launchctl", "list"]);
        return isListedInLaunchctl(stdout, bundleId);
    }
    catch {
        return false;
    }
}
/**
 * True when `launchctl list` output has the app's own job, `UIKitApplication:<bundleId>[…]`.
 *
 * A prefix match is not enough: an XCUITest runner's bundle id extends the app's
 * (`com.example.app.AppUITests.xctrunner`), so while a UI-test harness is up the app
 * always looked "running" and every file write was refused.
 */
export function isListedInLaunchctl(launchctlList, bundleId) {
    const label = `UIKitApplication:${bundleId}`;
    return launchctlList.split("\n").some((line) => {
        const start = line.indexOf(label);
        if (start < 0)
            return false;
        const next = line.charAt(start + label.length);
        return next === "[" || next === "" || /\s/.test(next);
    });
}
/**
 * All currently booted simulator UDIDs, across every runtime.
 *
 * `-j` is parsed rather than the human-readable listing because that one
 * groups by runtime under headers, which is exactly the shape that made the
 * `lens doctor` script's line-range slice miss a second booted device.
 */
async function bootedDeviceUDIDs() {
    try {
        const { stdout } = await run("xcrun", ["simctl", "list", "devices", "booted", "-j"]);
        const parsed = JSON.parse(stdout);
        const udids = [];
        for (const devices of Object.values(parsed.devices)) {
            for (const device of devices) {
                if (device.state === "Booted")
                    udids.push(device.udid);
            }
        }
        return udids;
    }
    catch {
        return [];
    }
}
async function containerForDevice(udid, bundleId) {
    try {
        const { stdout } = await run("xcrun", ["simctl", "get_app_container", udid, bundleId, "data"]);
        const path = stdout.trim();
        return path && existsSync(path) ? path : null;
    }
    catch {
        return null;
    }
}
/**
 * Data container of an app installed on a booted simulator.
 *
 * `simctl` returns the *data* container, which is the one holding Application
 * Support — the bundle container next to it has no writable trace in it.
 *
 * With more than one simulator booted, plain `simctl ... booted ...` picks
 * one silently — not necessarily the one actually in use, which reads as an
 * empty trace with no explanation. `NETWORKLENS_UDID` pins a device outright;
 * otherwise, with more than one candidate, whichever has the most recently
 * written trace.ndjson wins, and the choice is logged to stderr since it was
 * a real guess.
 */
export async function bootedAppContainer(bundleId) {
    const pinned = process.env.NETWORKLENS_UDID;
    if (pinned)
        return containerForDevice(pinned, bundleId);
    const udids = await bootedDeviceUDIDs();
    if (udids.length <= 1) {
        return containerForDevice(udids[0] ?? "booted", bundleId);
    }
    const candidates = [];
    for (const udid of udids) {
        const container = await containerForDevice(udid, bundleId);
        if (!container)
            continue;
        const tracePath = join(container, TRACE_RELATIVE_PATH);
        let mtimeMs = -1;
        try {
            mtimeMs = statSync(tracePath).mtimeMs;
        }
        catch {
            // no trace yet on this one — still a valid candidate, just least preferred.
        }
        candidates.push({ udid, path: container, mtimeMs });
    }
    if (candidates.length === 0)
        return null;
    candidates.sort((a, b) => b.mtimeMs - a.mtimeMs);
    if (candidates.length > 1) {
        const others = candidates.slice(1).map((c) => c.udid).join(", ");
        process.stderr.write(`networklens: ${bundleId} is installed on ${candidates.length} booted simulators; using ${candidates[0].udid} (most recently written trace). Also booted with the app installed: ${others}. Set NETWORKLENS_UDID to pin one explicitly.\n`);
    }
    return candidates[0].path;
}
