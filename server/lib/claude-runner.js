// Spawns one headless `claude -p` session and streams its events into a dashboard job. Everything
// that needs the user's plugins, MCP servers or claude.ai connectors (▶ Run, Confluence load) goes
// through here, so the dashboard holds no credentials of its own for those services.
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import { appendLine } from "./jobs.js";
import { formatEvent, lineSplitter } from "./claude-stream.js";
import { usageFeed } from "./usage.js";

/**
 * Resolves `{ code, result, toolResults }` when the session exits. `toolResults` holds the raw
 * content of every tool result, keyed by tool name — a caller that only needs data a tool returned
 * (a page body) reads it here instead of asking Claude to re-type it, which costs output tokens and
 * risks paraphrase.
 */
export function runClaude(job, { prompt, args = [], cwd }) {
	appendLine(job, `● starting claude -p "${prompt.length > 160 ? `${prompt.slice(0, 160)}…` : prompt}"`);
	// stdin ignored: with an open pipe the CLI waits 3 s for piped input and warns before starting.
	const child = spawn("claude", ["-p", prompt, "--output-format", "stream-json", "--verbose", ...args], {
		cwd,
		env: process.env,
		stdio: ["ignore", "pipe", "pipe"],
	});
	job.onCancel = () => child.kill("SIGTERM");

	let result = null;
	const toolNames = new Map();
	const toolResults = {};
	const stdout = lineSplitter((rawLine) => {
		const { lines, result: final } = formatEvent(rawLine);
		lines.forEach((line) => appendLine(job, line));
		if (final) result = final;
		collectToolData(rawLine, toolNames, toolResults, job.id);
	});
	const stderr = lineSplitter((line) => appendLine(job, line));
	child.stdout.on("data", (chunk) => stdout.push(String(chunk)));
	child.stderr.on("data", (chunk) => stderr.push(String(chunk)));

	return new Promise((resolve) => {
		child.on("error", (error) => {
			appendLine(job, `! failed to spawn claude: ${error.message}`);
			resolve({ code: -1, result: null, toolResults });
		});
		child.on("close", (code) => {
			stdout.flush();
			stderr.flush();
			resolve({ code, result, toolResults });
		});
	});
}

function collectToolData(rawLine, toolNames, toolResults, runKey) {
	let event;
	try {
		event = JSON.parse(rawLine);
	} catch {
		return;
	}
	usageFeed.noteMessage(event, runKey);
	for (const part of event.message?.content ?? []) {
		if (event.type === "assistant" && part.type === "tool_use") toolNames.set(part.id, part.name);
		// is_error results are kept too: an oversized result arrives as an error-shaped "saved to <file>" notice.
		if (event.type !== "user" || part.type !== "tool_result") continue;
		const name = toolNames.get(part.tool_use_id);
		const text = typeof part.content === "string"
			? part.content
			: (part.content ?? []).map((piece) => piece.text ?? "").join("");
		if (name) (toolResults[name] ??= []).push(followPersistedResult(text));
	}
}

/** Claude Code swaps a very large tool result (~100k+ chars, e.g. a Jira search) for a notice that
 *  names the file it saved the full result to; read that file so callers always get the data. */
function followPersistedResult(text) {
	const saved = text.startsWith("Error: result (") ? text.match(/saved to (\/\S+?\.txt)\./)?.[1] : null;
	if (!saved) return text;
	try {
		return readFileSync(saved, "utf8");
	} catch {
		return text;
	}
}
