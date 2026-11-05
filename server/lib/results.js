// P5 — Results and validation (workflow-plan §⑦, D-062). Every batch run is kept with what it
// tested (code, build, simulator) and, per case, the evidence the run left behind. A person reviews
// each verdict — Accept, Override (with a reason) or Needs re-run — and the run counts as Validated
// only when every case is accepted or overridden. "Re-run failed" runs the failures once more; a
// case that fails and then passes is FLAKY, never PASS.
import { EventEmitter } from "node:events";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { basename, dirname, join } from "node:path";

const KEEP_RUNS = 50;
const REVIEW_ACTIONS = new Set(["accept", "override", "rerun"]);

/** Readiness and harness liveness probes were once swept into evidence; they are never proof. */
export const isProbeShot = (path) => /(harness|readiness)-probe/.test(String(path));

export const isPass = (verdict) => String(verdict ?? "").startsWith("PASS");

/**
 * What a case finally counts as: the reviewer's override wins; a failure that passed on its re-run
 * is FLAKY; otherwise the run's own verdict.
 */
export function finalVerdict(item) {
	if (item.review?.action === "override") return item.review.verdict;
	if (item.rerun && !isPass(item.verdict) && isPass(item.rerun.verdict)) return "FLAKY";
	return item.verdict ?? item.status?.toUpperCase() ?? "—";
}

export function reviewState(run) {
	const reviewed = run.items.filter((item) => item.review?.action === "accept" || item.review?.action === "override").length;
	return { reviewed, total: run.items.length, isValidated: run.items.length > 0 && reviewed === run.items.length };
}

/** Cases "Re-run failed" picks: not passing (and not yet re-run), or marked Needs re-run. */
export function rerunCandidates(run) {
	return run.items
		.map((item, index) => ({ item, index }))
		.filter(({ item }) => item.review?.action === "rerun" || (!item.rerun && ["done"].includes(item.status) && !isPass(item.verdict)));
}

/** Emits `change` after every mutation, so the `results` slice re-reads (D-087). */
export class ResultsStore extends EventEmitter {
	constructor(dataDir) {
		super();
		this.path = join(dataDir, "results.json");
		this.runs = [];
		this.saveChain = Promise.resolve();
	}

	async restore() {
		try {
			this.runs = JSON.parse(await readFile(this.path, "utf8"));
		} catch {
			this.runs = [];
		}
		// A run that was going when the dashboard stopped can't continue.
		for (const run of this.runs) {
			if (run.status === "running" || run.status === "paused") {
				run.status = "interrupted";
				for (const item of run.items) if (["queued", "running", "skipping"].includes(item.status)) Object.assign(item, { status: "cancelled", verdict: item.verdict ?? "INTERRUPTED" });
			}
		}
		return this.runs;
	}

	#save() {
		this.emit("change");
		this.saveChain = this.saveChain.then(async () => {
			await mkdir(dirname(this.path), { recursive: true });
			const temporary = `${this.path}.tmp-${process.pid}`;
			await writeFile(temporary, JSON.stringify(this.runs.slice(0, KEEP_RUNS), null, 2));
			await rename(temporary, this.path);
		}).catch(() => {});
		return this.saveChain;
	}

	/** Drops every finished run (Reset, D-108); a running or paused one stays. Returns how many went. */
	clearFinished() {
		const before = this.runs.length;
		this.runs = this.runs.filter((run) => run.status === "running" || run.status === "paused");
		this.#save();
		return before - this.runs.length;
	}

	get(id) {
		return this.runs.find((run) => run.id === id) ?? null;
	}

	list() {
		return this.runs.map(runSummary);
	}

	/** Takes a batch snapshot; keeps what only the store knows (manifest, reviews, re-runs, evidence). */
	upsert(snapshot, extra = {}) {
		const existing = this.get(snapshot.id);
		const updatedAt = new Date().toISOString();
		if (!existing) {
			this.runs.unshift({ ...snapshot, ...extra, updatedAt });
		} else {
			const items = snapshot.items.map((item, index) => {
				const kept = existing.items[index] ?? {};
				return { ...kept, ...item, review: kept.review, rerun: kept.rerun, evidence: item.evidence ?? kept.evidence };
			});
			Object.assign(existing, snapshot, extra, { items, manifest: existing.manifest ?? extra.manifest, updatedAt });
		}
		return this.#save();
	}

	review(runId, index, { action, verdict, reason, by = "you" }) {
		const run = this.get(runId);
		const item = run?.items[index];
		if (!item) throw new Error("no such case in that run");
		if (!REVIEW_ACTIONS.has(action)) throw new Error("action must be accept, override or rerun");
		if (action === "override") {
			if (!["PASS", "FAIL"].includes(verdict)) throw new Error("override to PASS or FAIL");
			if (String(reason ?? "").trim().length < 5) throw new Error("say why you override the verdict (a few words)");
		}
		run.updatedAt = new Date().toISOString();
		item.review = { action, ...(action === "override" ? { verdict } : {}), ...(reason ? { reason: String(reason).trim() } : {}), by, at: new Date().toISOString() };
		this.#save();
		return run;
	}

	/** Records a re-run's verdict on the case it re-ran; a pass after a failure makes it FLAKY. */
	recordRerun(runId, index, { verdict, batchId }) {
		const run = this.get(runId);
		const item = run?.items[index];
		if (!item) return;
		run.updatedAt = new Date().toISOString();
		item.rerun = { verdict, batchId, at: new Date().toISOString() };
		if (item.review?.action === "rerun") delete item.review;
		this.#save();
	}
}

/** One row of the run list: outcome, review progress and what was tested. `updatedAt` moves on any change. */
export function runSummary(run) {
	const manifest = run.manifest ?? {};
	return {
		id: run.id,
		createdAt: run.createdAt,
		endedAt: run.endedAt ?? null,
		updatedAt: run.updatedAt ?? run.endedAt ?? run.createdAt,
		status: run.status,
		rerunOf: run.rerunOf ?? null,
		bundleId: run.bundleId ?? null,
		cases: run.items.length,
		caseIds: run.items.map((item) => item.caseId),
		counts: countFinal(run),
		...reviewState(run),
		branch: manifest.branch ?? null,
		codeId: manifest.codeId ?? null,
		hasLocalChanges: Boolean(manifest.hasLocalChanges),
		isUnverified: Boolean(manifest.isUnverified),
		simulator: manifest.simulator ?? null,
		environment: manifest.environment ?? null,
		pauseReason: run.status === "paused" ? run.pauseReason ?? null : null,
	};
}

/** Newest run per branch (runs are kept newest first), with how many runs that branch has. */
export function branchHistory(runs) {
	const byBranch = new Map();
	for (const run of runs) {
		const branch = run.manifest?.branch ?? "unknown";
		const entry = byBranch.get(branch);
		if (entry) entry.runCount += 1;
		else byBranch.set(branch, { branch, runCount: 1, latest: runSummary(run) });
	}
	return [...byBranch.values()];
}

const sharesCase = (left, right) => left.items.some((item) => right.items.some((other) => other.caseId === item.caseId));

/**
 * What a run is compared with when none is picked: the newest earlier run on develop that shares a
 * case, else the newest earlier run (any branch) that shares one.
 */
export function defaultBaseRun(runs, head) {
	const earlier = runs.filter((run) => run.id !== head.id && run.createdAt < head.createdAt && sharesCase(run, head));
	return earlier.find((run) => run.manifest?.branch === "develop") ?? earlier[0] ?? null;
}

/** Per case: base vs head final verdicts and the change — newlyFailing · fixed · same · added · notRun. */
export function compareRuns(base, head) {
	const baseItems = new Map((base?.items ?? []).map((item) => [item.caseId, item]));
	const rows = head.items.map((item) => {
		const before = baseItems.get(item.caseId);
		const headVerdict = finalVerdict(item);
		const baseVerdict = before ? finalVerdict(before) : null;
		let change = "added";
		if (before) {
			const wasPassing = isPass(baseVerdict);
			const isPassing = isPass(headVerdict);
			change = wasPassing === isPassing ? "same" : isPassing ? "fixed" : "newlyFailing";
		}
		return { caseId: item.caseId, scenario: item.scenario ?? before?.scenario ?? "", base: baseVerdict, head: headVerdict, change };
	});
	for (const [caseId, item] of baseItems) {
		if (!head.items.some((entry) => entry.caseId === caseId)) rows.push({ caseId, scenario: item.scenario ?? "", base: finalVerdict(item), head: null, change: "notRun" });
	}
	const counts = { newlyFailing: 0, fixed: 0, same: 0, added: 0, notRun: 0 };
	for (const row of rows) counts[row.change] += 1;
	return { base: base ? runSummary(base) : null, head: runSummary(head), rows, counts };
}

function countFinal(run) {
	const counts = {};
	for (const item of run.items) {
		const verdict = finalVerdict(item);
		const key = isPass(verdict) ? "PASS" : verdict === "FLAKY" ? "FLAKY" : /^FAIL/.test(verdict) ? "FAIL" : /^BLOCKED/.test(verdict) ? "BLOCKED" : verdict;
		counts[key] = (counts[key] ?? 0) + 1;
	}
	return counts;
}

const cell = (text) => String(text ?? "").replace(/\|/g, "\\|").replace(/\n/g, " ");

/** The shareable report: manifest, summary, per-case table, evidence, review trail. Markdown. */
export function buildReport(run) {
	const { reviewed, total, isValidated } = reviewState(run);
	const counts = countFinal(run);
	const manifest = run.manifest ?? {};
	const lines = [
		`# QA run — ${new Date(run.createdAt).toLocaleString("en-GB")}`,
		"",
		`**Status:** ${isValidated ? "✅ Validated" : `⏳ ${reviewed} of ${total} cases reviewed`} · ${Object.entries(counts).map(([key, count]) => `${count} ${key}`).join(" · ")}`,
		"",
		"## What was tested",
		"",
		`- **Code:** ${manifest.branch ?? "—"} @ ${manifest.codeId ?? "—"}${manifest.hasLocalChanges ? " (local changes)" : ""}`,
		`- **Build:** ${manifest.builtFrom ?? "—"}${manifest.isUnverified ? " — ⚠ UNVERIFIED BUILD" : ""}${manifest.overrideReason ? ` (override: ${manifest.overrideReason})` : ""}`,
		`- **Simulator:** ${manifest.simulator ?? "—"}`,
		`- **Environment:** ${manifest.environment ?? "—"}`,
		`- **Approvals:** ${run.approval === "autonomous" ? "unattended" : "asked before anything unusual"}`,
		...(run.rerunOf ? [`- **Re-run of:** ${run.rerunOf}`] : []),
		"",
		"## Cases",
		"",
		"| Case | Ran as | Run verdict | Final | Review | Time | Evidence |",
		"|---|---|---|---|---|---|---|",
	];
	for (const item of run.items) {
		const review = item.review
			? `${item.review.action}${item.review.reason ? `: ${item.review.reason}` : ""}`
			: "not reviewed";
		const evidence = (item.evidence?.screenshots ?? []).filter((path) => !isProbeShot(path)).length;
		const videoCount = (item.evidence?.videos ?? []).length;
		lines.push(`| ${cell(item.caseId)} ${cell(item.scenario ?? "")} | ${item.mode === "replay" ? `macro ${cell(item.macroName ?? "")}` : "Claude"} | ${cell(item.verdict)}${item.rerun ? ` → re-run ${cell(item.rerun.verdict)}` : ""} | **${cell(finalVerdict(item))}** | ${cell(review)} | ${item.durationMs ? `${Math.round(item.durationMs / 1000)} s` : "—"} | ${evidence} screenshot(s)${videoCount ? ` + ${videoCount} video` : ""} |`);
	}
	for (const item of run.items) {
		const details = [];
		if (item.triage) details.push(`- 🩺 **Claude's triage:** ${item.triage.kind} — ${item.triage.summary}`, ...(item.triage.changedFiles ?? []).map((file) => `  - ${file.change}: \`${file.path}\``));
		if (item.repaired) details.push(`- 🔧 **Macro repaired by Claude**, then replayed by the driver (before the repair: ${item.verdictBeforeRepair})`);
		if (item.learned) details.push(item.learned.ok ? `- 📝 **Saved as macro** “${item.learned.macroName}” (\`${basename(item.learned.path)}\`) — its replay passed` : `- 📝 Not saved as a macro: ${item.learned.reason ?? `replay ${item.learned.replayVerdict}`}`);
		if (item.crash) details.push(`- 💥 **App crashed:** ${item.crash.exception ?? ""} — \`${basename(item.crash.path ?? "")}\``, ...(item.crash.frames ?? []).slice(0, 5).map((frame) => `  - \`${frame}\``));
		const mocks = Object.entries(item.evidence?.mocksServed ?? {});
		if (mocks.length) details.push(`- **Mocked responses:** ${mocks.map(([key, count]) => `${key} ×${count}`).join(", ")}`);
		// File names only: a local path means nothing on Confluence and carries the Mac's user name.
		for (const shot of (item.evidence?.screenshots ?? []).filter((path) => !isProbeShot(path))) details.push(`- \`${basename(shot)}\``);
		for (const video of item.evidence?.videos ?? []) details.push(`- 🎬 \`${basename(video)}\``);
		if (item.evidence?.summary) details.push("", "> " + item.evidence.summary.replace(/\n/g, "\n> "));
		if (details.length) lines.push("", `### ${item.caseId}`, "", ...details);
	}
	return `${lines.join("\n")}\n`;
}
