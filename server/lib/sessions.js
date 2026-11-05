// Registry of dashboard Claude sessions: creates them, persists the index (`.data/sessions.json`),
// and restores them after a restart as resumable (the Claude process starts again on next message).
import { EventEmitter } from "node:events";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { basename, join } from "node:path";
import { randomUUID } from "node:crypto";
import { ClaudeSession } from "./claude-session.js";
import { AlwaysAllowStore } from "./permissions.js";

export class SessionManager extends EventEmitter {
	constructor(dataDir) {
		super();
		this.setMaxListeners(100);
		this.dataDir = dataDir;
		this.indexPath = join(dataDir, "sessions.json");
		this.alwaysAllow = new AlwaysAllowStore(join(dataDir, "permissions.json"));
		this.sessions = new Map();
		this.saveTimer = null;
	}

	async restore() {
		let records = [];
		try {
			records = JSON.parse(await readFile(this.indexPath, "utf8"));
		} catch {
			return;
		}
		for (const record of records) {
			// A process that was live when the dashboard stopped is gone; its conversation resumes on demand.
			if (!["closed", "error"].includes(record.status)) record.status = "idle";
			this.#adopt(record, {});
		}
	}

	/**
	 * `options`: { allowedTools, disallowedTools, permissionMode, autoClose } — engine settings for this
	 * session only. `meta` links the session to what spawned it (task, case).
	 */
	create({ projectDir, title, model, meta = {}, options = {} }) {
		const now = new Date().toISOString();
		const record = {
			id: randomUUID(),
			title: title || `Session in ${basename(projectDir)}`,
			projectDir,
			model: model || null,
			claudeSessionId: null,
			status: "idle",
			createdAt: now,
			updatedAt: now,
			costUsd: 0,
			turns: 0,
			lastText: "",
			meta,
		};
		const session = this.#adopt(record, options);
		session.isHistoryLoaded = true;
		this.#scheduleSave();
		this.emit("created", session.summary());
		this.emit("change", session.summary());
		return session;
	}

	get(id) {
		return this.sessions.get(id);
	}

	list() {
		return [...this.sessions.values()].map((session) => session.summary())
			.sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
	}

	/** Removes a session from the dashboard (its Claude transcript stays in ~/.claude). */
	remove(id) {
		const session = this.sessions.get(id);
		if (!session) return false;
		session.close();
		this.sessions.delete(id);
		this.#scheduleSave();
		this.emit("removed", id);
		return true;
	}

	/** Removes every session that isn't live or waiting on an answer, with its saved transcript (Reset, D-108). */
	async removeFinished() {
		const finished = [...this.sessions.values()].filter((session) => !session.isLive && session.pending.size === 0);
		for (const session of finished) {
			this.remove(session.id);
			await rm(join(this.dataDir, "sessions", `${session.id}.ndjson`), { force: true });
		}
		return finished.length;
	}

	#adopt(record, options) {
		const session = new ClaudeSession(record, {
			dataDir: this.dataDir,
			alwaysAllow: this.alwaysAllow,
			options,
			onChange: () => {
				this.#scheduleSave();
				this.emit("change", session.summary());
			},
		});
		this.sessions.set(record.id, session);
		return session;
	}

	#scheduleSave() {
		clearTimeout(this.saveTimer);
		this.saveTimer = setTimeout(async () => {
			await mkdir(this.dataDir, { recursive: true });
			await writeFile(this.indexPath, JSON.stringify([...this.sessions.values()].map((session) => session.record), null, 2));
		}, 300);
	}
}
