// D-149: only live interactive CLI sessions count; Remote Control = a bridgeSessionId.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { listCliSessions } from "../lib/claude-cli-sessions.js";

test("lists live sessions and their Remote Control state", async () => {
	const dir = await mkdtemp(join(tmpdir(), "cli-sessions-"));
	await writeFile(join(dir, "1.json"), JSON.stringify({ pid: 1, name: "a", kind: "interactive", bridgeSessionId: "session_x" }));
	await writeFile(join(dir, "2.json"), JSON.stringify({ pid: 2, name: "b", kind: "interactive" }));
	await writeFile(join(dir, "3.json"), JSON.stringify({ pid: 3, name: "dead", kind: "interactive", bridgeSessionId: "s" }));
	await writeFile(join(dir, "4.json"), "{ half");
	await writeFile(join(dir, "1.abc.key"), "secret");
	const { sessions, isReadable } = await listCliSessions({ dir, alive: (pid) => pid !== 3 });
	assert.equal(isReadable, true);
	assert.deepEqual(sessions.map((s) => [s.name, s.isRemoteControl]).sort(), [["a", true], ["b", false]]);
});

test("a missing registry is reported as unreadable, not as no sessions", async () => {
	const result = await listCliSessions({ dir: join(tmpdir(), "does-not-exist-cli") });
	assert.deepEqual(result, { sessions: [], isReadable: false });
});
