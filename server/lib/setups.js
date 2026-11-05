// P9 — Saved setups (workflow-plan §5). A setup is what a repeat run needs, named once: which code
// (repo + GitHub branch or the local folder), which test document, which cases, and how Claude
// may act on the cases with no macro. Home lists them with "▶ Run again", which brings the code and
// the document back to that state and starts the batch — the two-minute repeat path.
import { randomUUID } from "node:crypto";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { join } from "node:path";

const KEEP_SETUPS = 50;

/** The fields a setup is made of, checked; throws a message a person can act on. */
export function makeSetup({ name, code, doc, caseIds, approval, techDocPath }) {
	const trimmedName = String(name ?? "").trim();
	if (!trimmedName) throw new Error("give the setup a name");
	if (!code?.repo || !["github", "local"].includes(code.source)) throw new Error("prepare the code first (Question 1)");
	if (code.source === "github" && !code.branch) throw new Error("the prepared code has no branch");
	if (!doc?.source) throw new Error("load the test cases first");
	const ids = [...new Set((caseIds ?? []).map(String))];
	if (ids.length === 0) throw new Error("tick the cases the setup runs");
	return {
		name: trimmedName.slice(0, 80),
		code: { source: code.source, repo: code.repo, ...(code.source === "github" && { branch: code.branch }) },
		doc: { source: doc.source, title: doc.title ?? null },
		caseIds: ids,
		approval: approval === "autonomous" ? "autonomous" : "ask",
		...(techDocPath && { techDocPath: String(techDocPath) }),
	};
}

/**
 * Whether Run again must prepare the code first: different repo or source, another branch, a
 * GitHub branch (always re-fetched: a setup means "the latest of this branch"), or a local folder
 * that changed since it was snapshotted.
 */
export function needsPrepare(setup, manifest, drift) {
	if (!manifest) return true;
	if (manifest.repo !== setup.code.repo || manifest.source !== setup.code.source) return true;
	if (setup.code.source === "github") return true;
	return Boolean(drift?.hasDrifted);
}

export class SetupStore {
	constructor(dataDir) {
		this.path = join(dataDir, "setups.json");
	}

	async list() {
		try {
			return JSON.parse(await readFile(this.path, "utf8"));
		} catch {
			return [];
		}
	}

	async #write(setups) {
		await mkdir(join(this.path, ".."), { recursive: true });
		const temporary = `${this.path}.tmp-${process.pid}`;
		await writeFile(temporary, JSON.stringify(setups.slice(0, KEEP_SETUPS), null, 2));
		await rename(temporary, this.path);
	}

	async get(id) {
		return (await this.list()).find((setup) => setup.id === id) ?? null;
	}

	/** Saves a new setup; one with the same name is replaced (it keeps its id). */
	async save(fields) {
		const setup = makeSetup(fields);
		const setups = await this.list();
		const existing = setups.find((entry) => entry.name.toLowerCase() === setup.name.toLowerCase());
		const saved = { id: existing?.id ?? randomUUID(), createdAt: existing?.createdAt ?? new Date().toISOString(), updatedAt: new Date().toISOString(), lastRun: existing?.lastRun ?? null, ...setup };
		await this.#write([saved, ...setups.filter((entry) => entry !== existing)]);
		return saved;
	}

	async remove(id) {
		const setups = await this.list();
		const kept = setups.filter((setup) => setup.id !== id);
		if (kept.length === setups.length) return false;
		await this.#write(kept);
		return true;
	}

	async noteRun(id, lastRun) {
		const setups = await this.list();
		const setup = setups.find((entry) => entry.id === id);
		if (!setup) return;
		setup.lastRun = lastRun;
		await this.#write(setups);
	}
}
