// D-149: the Claude Code CLI sessions running on this Mac, read from the CLI's own registry
// (~/.claude/sessions/<pid>.json). A session with Remote Control connected carries a `bridgeSessionId`.
// Undocumented CLI files: anything unreadable is skipped, and the Mac shows "unknown" rather than "off" on failure.
import { readdir, readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

export const CLI_SESSIONS_DIR = join(homedir(), ".claude", "sessions");

function isAlive(pid) {
	try {
		process.kill(pid, 0);
		return true;
	} catch (error) {
		return error.code === "EPERM";
	}
}

/** Live interactive CLI sessions: `{ pid, name, cwd, status, isRemoteControl, version }`. */
export async function listCliSessions({ dir = CLI_SESSIONS_DIR, alive = isAlive } = {}) {
	let names;
	try {
		names = (await readdir(dir)).filter((name) => /^\d+\.json$/.test(name));
	} catch {
		return { sessions: [], isReadable: false };
	}
	const sessions = [];
	for (const name of names) {
		try {
			const record = JSON.parse(await readFile(join(dir, name), "utf8"));
			if (!Number.isInteger(record.pid) || !alive(record.pid)) continue;
			if (record.kind && record.kind !== "interactive") continue;
			sessions.push({
				pid: record.pid,
				name: record.name ?? null,
				cwd: record.cwd ?? null,
				status: record.status ?? null,
				isRemoteControl: Boolean(record.bridgeSessionId),
				version: record.version ?? null,
			});
		} catch {
			// A file mid-write or of another shape — skip it.
		}
	}
	return { sessions, isReadable: true };
}
