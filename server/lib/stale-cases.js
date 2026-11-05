// F1 (D-188): remembers each built snapshot's commit and local edits, and answers "which app files differ
// between the build a result ran on and the build under test now" — cached, since builds rarely change.
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { changedBetween, localHashes } from "./staleness.js";

export class StaleChecker {
	#file;
	#diffNames;
	#snapshots = null;
	#changed = new Map();

	/** `diffNames(fromSha, toSha)` lists the repo-relative files a commit range changes. */
	constructor(file, { diffNames }) {
		this.#file = file;
		this.#diffNames = diffNames;
	}

	async #load() {
		this.#snapshots ??= JSON.parse(await readFile(this.#file, "utf8").catch(() => "{}"));
		return this.#snapshots;
	}

	/** Records the snapshot the current build came from, while its QA copy still holds that code. */
	async remember(stamp, manifest) {
		const snapshots = await this.#load();
		if (!stamp?.builtFrom || snapshots[stamp.builtFrom] || !manifest || manifest.snapshotId !== stamp.builtFrom) return;
		snapshots[stamp.builtFrom] = { sha: manifest.sha, local: await localHashes(manifest.path, manifest.changedFiles ?? []), at: new Date().toISOString() };
		await mkdir(dirname(this.#file), { recursive: true });
		await writeFile(this.#file, JSON.stringify(snapshots, null, 2));
	}

	/** App files that differ between two built snapshots; null when either is unknown or git can't compare. */
	async changed(fromCodeId, toCodeId) {
		const key = `${fromCodeId}→${toCodeId}`;
		if (!this.#changed.has(key)) {
			const snapshots = await this.#load();
			this.#changed.set(key, await changedBetween(snapshotOf(fromCodeId, snapshots), snapshotOf(toCodeId, snapshots), this.#diffNames).catch(() => null));
		}
		return this.#changed.get(key);
	}
}

/** A snapshot never recorded is still comparable when it had no local edits: its id is then the commit. */
function snapshotOf(codeId, snapshots) {
	if (snapshots[codeId]) return snapshots[codeId];
	return codeId && !String(codeId).includes("+") ? { sha: codeId, local: {} } : null;
}
