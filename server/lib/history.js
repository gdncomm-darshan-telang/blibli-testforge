// Append-only run history, so past Test Cases tab runs stay reviewable after the dashboard
// restarts. Small and infrequent enough that whole-file read/rewrite is simpler than a real store.
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const HISTORY_PATH = join(__dirname, "..", ".data", "runs.json");
const MAX_ENTRIES = 500;

async function readAll() {
	try {
		return JSON.parse(await readFile(HISTORY_PATH, "utf8"));
	} catch {
		return [];
	}
}

export async function appendRun(entry) {
	const all = await readAll();
	all.unshift({ ...entry, recordedAt: new Date().toISOString() });
	await mkdir(dirname(HISTORY_PATH), { recursive: true });
	await writeFile(HISTORY_PATH, JSON.stringify(all.slice(0, MAX_ENTRIES), null, 2));
}

export async function listRuns(limit = 100) {
	return (await readAll()).slice(0, limit);
}

/** Empties the run history (Reset, D-108). Returns how many entries went. */
export async function clearRuns() {
	const count = (await readAll()).length;
	await mkdir(dirname(HISTORY_PATH), { recursive: true });
	await writeFile(HISTORY_PATH, "[]");
	return count;
}
