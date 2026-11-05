// Video proof for a run (R4k, D-110): `simctl io recordVideo` on the QA simulator around one case.
// simctl only finalises the movie on SIGINT, so stop() interrupts it and waits for the file to be written.
import { execFile, spawn as spawnProcess } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdir, rename, rm, stat } from "node:fs/promises";
import { promisify } from "node:util";
import { dirname } from "node:path";

const STOP_TIMEOUT_MS = 20_000;
const runFile = promisify(execFile);

/** Starts recording `udid` into `path`; resolves once simctl reports it is recording (or after 3 s). */
export async function startVideo({ udid, path, spawn = spawnProcess }) {
	await mkdir(dirname(path), { recursive: true });
	const child = spawn("xcrun", ["simctl", "io", udid, "recordVideo", "--codec=h264", "--force", path], { stdio: ["ignore", "pipe", "pipe"] });
	let output = "";
	const exited = new Promise((resolve) => child.on("exit", (code) => resolve(code)));
	await new Promise((resolve) => {
		const timer = setTimeout(resolve, 3_000);
		const onData = (chunk) => {
			output += chunk.toString();
			if (/Recording started/i.test(output)) {
				clearTimeout(timer);
				resolve();
			}
		};
		child.stdout?.on("data", onData);
		child.stderr?.on("data", onData);
		exited.then(() => {
			clearTimeout(timer);
			resolve();
		});
	});
	return {
		path,
		/** Stops and returns the movie's path, or null when simctl never produced one. */
		async stop() {
			if (child.exitCode === null) child.kill("SIGINT");
			await Promise.race([exited, new Promise((resolve) => setTimeout(resolve, STOP_TIMEOUT_MS))]);
			if (child.exitCode === null) child.kill("SIGKILL");
			const info = await stat(path).catch(() => null);
			return info && info.size > 0 ? path : null;
		},
		output: () => output,
	};
}

/**
 * Cuts the movie at `path` to its last `seconds` in place (stream copy, no re-encode) with ffmpeg (D-113). Without
 * ffmpeg, or when the cut fails, the full movie is kept. Resolves to `path`.
 */
export async function trimToLast(path, seconds, { run = runFile } = {}) {
	const ffmpeg = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"].find((candidate) => existsSync(candidate));
	if (!ffmpeg) return path;
	const cut = path.replace(/(\.\w+)$/, ".cut$1");
	try {
		await run(ffmpeg, ["-v", "error", "-y", "-sseof", `-${seconds}`, "-i", path, "-c", "copy", "-movflags", "+faststart", cut]);
		await rename(cut, path);
	} catch {
		await rm(cut, { force: true }).catch(() => {});
	}
	return path;
}
