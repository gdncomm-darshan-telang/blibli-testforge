// D-147: a closed run session can be messaged again once reopened; one that never started Claude cannot.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { ClaudeSession } from "../lib/claude-session.js";

async function closedSession(claudeSessionId) {
	const dataDir = await mkdtemp(join(tmpdir(), "reopen-"));
	const record = { id: "s1", title: "▶ SF-001", projectDir: dataDir, status: "closed", claudeSessionId, meta: {} };
	return new ClaudeSession(record, { dataDir, alwaysAllow: { add: async () => {}, allows: async () => false }, onChange: () => {} });
}

test("reopen makes a closed session idle and records it", async () => {
	const session = await closedSession("claude-123");
	session.reopen();
	assert.equal(session.record.status, "idle");
	assert.ok(session.events.some((event) => event.kind === "reopened"));
});

test("a session that never started Claude can't be reopened", async () => {
	const session = await closedSession(null);
	assert.throws(() => session.reopen(), /never started Claude/);
	assert.equal(session.record.status, "closed");
});
