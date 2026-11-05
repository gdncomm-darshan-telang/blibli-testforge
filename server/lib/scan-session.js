// Scan mode (D-086): a person walks the app while the plugin's scan_mode.py watches through the
// harness; the dashboard runs it as a child, sends its commands (mark / skip / stop) on stdin, and
// turns its `--events` lines into the `scan` state slice so the Mac app shows what is on screen now.
import { spawn as spawnProcess } from "node:child_process";
import { EventEmitter } from "node:events";
import { mkdirSync } from "node:fs";
import { join } from "node:path";

export const EVENT_PREFIX = "EVENT ";
const MAX_LINES = 60;

export function emptyScan() {
	return { isActive: false, isStopping: false, startedAt: null, endedAt: null, out: null, device: null, current: null, screens: [], skipped: 0, pollError: null, message: null, fatal: null, lines: [] };
}

/** Pure: folds one scan_mode.py event into the view. */
export function applyScanEvent(state, event) {
	switch (event.event) {
		case "started":
			return { ...state, device: event.device ?? null, out: event.out ?? state.out };
		case "screen":
			return {
				...state,
				current: {
					changedAt: event.at,
					elementCount: event.elementCount ?? 0,
					identifierCount: event.identifierCount ?? 0,
					identifiers: event.identifiers ?? [],
					isTruncated: Boolean(event.truncated),
					distinctSeen: event.distinctSeen ?? 0,
				},
			};
		case "mark": {
			const capture = { variant: event.variant, at: event.at, elementCount: event.elementCount, identifierCount: event.identifierCount, merged: event.merged ?? 0, isComplete: Boolean(event.complete) };
			const existing = state.screens.find((screen) => screen.name === event.name);
			const screens = existing
				? state.screens.map((screen) => (screen.name === event.name ? { ...screen, variants: [...screen.variants, capture] } : screen))
				: [...state.screens, { name: event.name, variants: [capture] }];
			return { ...state, screens, message: null };
		}
		case "markFailed":
			return { ...state, message: `Couldn't record “${event.name}”: ${event.error}` };
		case "skip":
			return { ...state, skipped: event.skipped ?? state.skipped + 1 };
		case "pollError":
			return { ...state, pollError: event.error };
		case "pollRecovered":
			return { ...state, pollError: null };
		case "ended":
			return { ...state, out: event.out ?? state.out, fatal: event.fatal ?? null };
		default:
			return state;
	}
}

export class ScanSession extends EventEmitter {
	#child = null;
	#state = emptyScan();

	constructor({ scriptPath, outDir, spawn = spawnProcess, now = () => new Date() }) {
		super();
		this.scriptPath = scriptPath;
		this.outDir = outDir;
		this.spawn = spawn;
		this.now = now;
	}

	get isActive() {
		return this.#state.isActive;
	}

	view() {
		return this.#state;
	}

	start() {
		if (this.#state.isActive) throw new Error("a scan is already running");
		if (!this.scriptPath) throw new Error("scan_mode.py not found — is the test-flow-recorder plugin installed?");
		mkdirSync(this.outDir, { recursive: true });
		const stamp = this.now().toISOString().replace(/[:.]/g, "-");
		const out = join(this.outDir, `scan-${stamp}.json`);
		this.#state = { ...emptyScan(), isActive: true, startedAt: this.now().toISOString(), out };
		const child = this.spawn("python3", ["-u", this.scriptPath, "--events", "--out", out], { stdio: ["pipe", "pipe", "pipe"] });
		this.#child = child;
		let buffered = "";
		const onData = (chunk) => {
			buffered += chunk.toString();
			const lines = buffered.split("\n");
			buffered = lines.pop();
			for (const line of lines) this.#handleLine(line);
		};
		child.stdout.on("data", onData);
		child.stderr.on("data", onData);
		child.on("error", (error) => this.#finish({ fatal: error.message }));
		child.on("exit", (code) => this.#finish({ fatal: code === 0 ? this.#state.fatal : this.#state.fatal ?? this.#lastLine() ?? `scan stopped (exit ${code})` }));
		this.#changed();
		return this.#state;
	}

	/** `mark <name>` / `skip` / `stop` on the script's stdin. */
	command(verb, name = "") {
		if (!this.#state.isActive || !this.#child) throw new Error("no scan is running");
		const line = name ? `${verb} ${name.replace(/\s+/g, " ").trim()}` : verb;
		this.#child.stdin.write(`${line}\n`);
		if (verb === "stop") {
			this.#state = { ...this.#state, isStopping: true };
			this.#changed();
		}
	}

	#handleLine(raw) {
		const line = raw.trimEnd();
		if (!line.trim()) return;
		if (line.startsWith(EVENT_PREFIX)) {
			try {
				this.#state = applyScanEvent(this.#state, JSON.parse(line.slice(EVENT_PREFIX.length)));
			} catch {
				// A malformed event is kept as a plain line below rather than ending the scan.
				this.#pushLine(line);
			}
		} else {
			this.#pushLine(line);
		}
		this.#changed();
	}

	#pushLine(line) {
		this.#state = { ...this.#state, lines: [...this.#state.lines, line].slice(-MAX_LINES) };
	}

	#lastLine() {
		return this.#state.lines.at(-1)?.trim() || null;
	}

	#finish({ fatal }) {
		if (!this.#state.isActive) return;
		this.#child = null;
		this.#state = { ...this.#state, isActive: false, isStopping: false, endedAt: this.now().toISOString(), fatal: fatal ?? null };
		this.emit("end", this.#state);
		this.#changed();
	}

	#changed() {
		this.emit("change", this.#state);
	}
}
