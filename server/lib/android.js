import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { mkdir, writeFile, unlink } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
const run = promisify(execFile);
/**
 * The Android half of path resolution.
 *
 * Everything here is additive: with no `NETWORKLENS_ANDROID_PACKAGE` set, not one
 * function in this file is called and the server behaves exactly as it did for iOS. That
 * is the whole point — one server, one set of twenty tools, two platforms, so the
 * `api-mock` and `tracker-validation` skills need no edits at all.
 *
 * The files are byte-compatible by construction (see the Android port's
 * `PackGoldenTest` and `TraceGoldenTest`), so once the bytes are on this machine nothing
 * downstream of here knows or cares which platform wrote them.
 */
const LENS_DIRECTORY = "files/networklens";
/**
 * App-specific external storage first.
 *
 * `adb pull` reaches it with **no `run-as`**, so it works against a release-signed
 * build and for anyone on the team. `run-as` needs a debuggable app and fails with a
 * message about the package not being debuggable, which reads as the tool being broken.
 */
function externalPath(pkg, file) {
    return `/sdcard/Android/data/${pkg}/${LENS_DIRECTORY}/${file}`;
}
function internalPath(file) {
    return `${LENS_DIRECTORY}/${file}`;
}
/** The adb binary, honouring ANDROID_HOME before falling back to PATH. */
function adbBinary() {
    const explicit = process.env.NETWORKLENS_ADB;
    if (explicit)
        return explicit;
    const roots = [process.env.ANDROID_HOME, process.env.ANDROID_SDK_ROOT, join(homedir(), "Library/Android/sdk")];
    for (const root of roots) {
        if (!root)
            continue;
        const candidate = join(root, "platform-tools", "adb");
        if (existsSync(candidate))
            return candidate;
    }
    return "adb";
}
/**
 * `-s` only when asked for.
 *
 * With two devices attached and no serial, adb fails rather than guessing — which is
 * correct, and the error names the fix, so it is passed through untouched.
 */
function adbArgs(args) {
    const serial = process.env.ANDROID_SERIAL;
    return serial ? ["-s", serial, ...args] : args;
}
async function adb(args) {
    const { stdout } = await run(adbBinary(), adbArgs(args), { maxBuffer: 64 * 1024 * 1024 });
    return stdout;
}
export function androidPackage() {
    return process.env.NETWORKLENS_ANDROID_PACKAGE;
}
/**
 * Size and mtime of a file on the device, or null if it is not there.
 *
 * The two numbers are the whole cache key: `TraceReader` already caches its parse on the
 * local file's mtime+size, so as long as a changed device file produces a changed local
 * file, that cache keeps working untouched.
 */
async function deviceStat(pkg, file) {
    const external = externalPath(pkg, file);
    try {
        const out = (await adb(["shell", "stat", "-c", "%s %Y", external])).trim();
        if (out && !/No such file/i.test(out))
            return { key: out, remote: external, viaRunAs: false };
    }
    catch {
        // Falls through to internal storage.
    }
    // A host that overrode storageDirectory to filesDir, or an app on an emulator image
    // with no external storage mounted.
    try {
        const out = (await adb(["shell", "run-as", pkg, "stat", "-c", "%s %Y", internalPath(file)])).trim();
        if (out && !/No such file/i.test(out))
            return { key: out, remote: internalPath(file), viaRunAs: true };
    }
    catch {
        return null;
    }
    return null;
}
/** Where a pulled file lands, keyed on the device's own size+mtime. */
function localCachePath(pkg, file, key) {
    const digest = createHash("sha1").update(`${pkg}:${file}:${key}`).digest("hex").slice(0, 16);
    return join(tmpdir(), "networklens-adb", pkg, `${digest}-${file}`);
}
/**
 * Pulls a lens file off the device, or returns null when there is nothing to pull.
 *
 * The local path encodes the device file's size and mtime, so a second call while the app
 * is idle re-uses the file already on disk and a call after new traffic writes a new one.
 * Pulling a 30 MB trace on every `lens_list` would make the tool unusable; re-parsing a
 * stale copy would make it wrong.
 */
export async function pullLensFile(pkg, file) {
    const stat = await deviceStat(pkg, file);
    if (!stat)
        return null;
    const local = localCachePath(pkg, file, stat.key);
    const how = `adb ${stat.viaRunAs ? "run-as" : "pull"} from ${pkg}`;
    if (existsSync(local))
        return { path: local, how };
    await mkdir(join(local, ".."), { recursive: true });
    if (!stat.viaRunAs) {
        await adb(["pull", stat.remote, local]);
        return { path: local, how };
    }
    // `run-as … cat` rather than a pull: adb cannot pull from a private data directory, and
    // exec-out keeps the bytes binary-clean where `adb shell` would translate newlines.
    const { stdout } = await run(adbBinary(), adbArgs(["exec-out", "run-as", pkg, "cat", stat.remote]), { maxBuffer: 128 * 1024 * 1024, encoding: "buffer" });
    await writeFile(local, stdout);
    return { path: local, how };
}
/**
 * Writes `session.json` back to the device.
 *
 * Staged through `/data/local/tmp` and moved into place, because a push straight onto the
 * live file can be read half-written by an app that launches mid-transfer — and a
 * half-read session file presents as every rule having vanished.
 */
export async function pushSessionFile(pkg, localPath) {
    const staged = `/data/local/tmp/networklens-session-${process.pid}.json`;
    await adb(["push", localPath, staged]);
    try {
        const external = externalPath(pkg, "session.json");
        await adb(["shell", "mkdir", "-p", `/sdcard/Android/data/${pkg}/${LENS_DIRECTORY}`]);
        await adb(["shell", "cp", staged, external]);
        return `adb push to ${external}`;
    }
    catch {
        // Internal storage needs the app's own uid to own the result, so the copy has to run
        // as the app rather than as shell.
        await adb(["shell", "run-as", pkg, "cp", staged, internalPath("session.json")]);
        return `adb run-as push into ${pkg} internal storage`;
    }
    finally {
        await adb(["shell", "rm", "-f", staged]).catch(() => { });
        await unlink(localPath).catch(() => { });
    }
}
/**
 * Whether the app is running on the device.
 *
 * Same reason as the iOS probe: the app owns `session.json` while it lives, reading it at
 * `start()` and autosaving its in-memory state back over it on every edit. A write made
 * while it runs is overwritten within seconds, and the only symptom is an empty Mocks tab.
 *
 * `pidof` is exact where `ps | grep` matches the grep itself. Unknown counts as not
 * running: refusing a legitimate write because a probe failed is the worse error.
 */
export async function isAndroidAppRunning(pkg) {
    try {
        const out = (await adb(["shell", "pidof", pkg])).trim();
        return out.length > 0;
    }
    catch {
        return false;
    }
}
/**
 * Opens the reverse tunnel the control channel needs on a physical device.
 *
 * On an emulator `127.0.0.1` is the emulator itself, so the app reaches the host at
 * `10.0.2.2` and the Android `ControlEndpointProbe` finds it unaided. A physical device
 * has neither, and `adb reverse` is the only way loopback on the device becomes loopback
 * on this machine — which makes the control channel work on real hardware, something the
 * iOS side cannot do at all.
 */
export async function openControlTunnel(port = 8788) {
    try {
        await adb(["reverse", `tcp:${port}`, `tcp:${port}`]);
        return { ok: true, detail: `adb reverse tcp:${port} tcp:${port}` };
    }
    catch (error) {
        return { ok: false, detail: `could not open the reverse tunnel: ${error.message}` };
    }
}
/** Diagnostic string for `lens_status`, so "no rows" has a visible cause. */
export async function androidDiagnostic(pkg) {
    const lines = [`Android package: ${pkg}`, `adb: ${adbBinary()}`];
    try {
        const devices = (await adb(["devices"])).trim().split("\n").slice(1).filter(Boolean);
        lines.push(devices.length ? `devices: ${devices.join(", ")}` : "devices: none attached");
    }
    catch (error) {
        lines.push(`adb devices failed: ${error.message}`);
    }
    lines.push(`app running: ${(await isAndroidAppRunning(pkg)) ? "yes" : "no"}`);
    const trace = await deviceStat(pkg, "trace.ndjson");
    lines.push(trace ? `trace: ${trace.remote} (${trace.key})` : "trace: not found on device — is TraceOptions set?");
    return lines.join("\n");
}
