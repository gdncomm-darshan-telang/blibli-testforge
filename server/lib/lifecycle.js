// One lifecycle for every action the UI shows (D-077): a task, a job, a batch or one of its items is
// always in exactly one of these phases, so every button renders from the phase instead of guessing
// from timers. The raw status stays alongside for anything that needs the detail.
export const PHASES = ["waiting", "working", "done", "failed", "cancelling", "cancelled"];

const BY_STATUS = {
	queued: "waiting",
	paused: "waiting",
	running: "working",
	skipping: "cancelling",
	done: "done",
	failed: "failed",
	error: "failed",
	cancelled: "cancelled",
};

/** `status` is a task, job, batch or batch-item status; `isCancelRequested` marks a cancel that the
 *  owner hasn't finished yet (a replay finishing its cleanup steps). */
export function phaseOf(status, { isCancelRequested = false } = {}) {
	if (typeof status !== "string") return "waiting";
	// The task queue parks device-lane tasks as "waiting-…" while the simulator is held.
	const phase = status.startsWith("waiting") ? "waiting" : BY_STATUS[status] ?? "working";
	if (isCancelRequested && (phase === "working" || phase === "waiting")) return "cancelling";
	return phase;
}

export const isFinished = (phase) => phase === "done" || phase === "failed" || phase === "cancelled";

/** Adds `phase` to a task as the queue lists it. */
export function withTaskPhase(task) {
	return { ...task, phase: phaseOf(task.status, { isCancelRequested: Boolean(task.isCancelRequested) }) };
}

/** A job (lib/jobs.js) as the stream shows it: no buffered lines, just where it stands. */
export function jobView(job) {
	return {
		id: job.id,
		meta: job.meta,
		status: job.status,
		verdict: job.verdict,
		startedAt: job.startedAt,
		endedAt: job.endedAt,
		phase: phaseOf(job.status, { isCancelRequested: job.isCancelled }),
	};
}

/** A batch snapshot with a phase on the batch and on each item. */
export function withBatchPhases(batch) {
	if (!batch) return batch;
	// A cancelled batch marks itself cancelled at once, but its current case still runs its cleanup.
	const isStillStopping = (batch.items ?? []).some((item) => item.status === "running" || item.status === "skipping");
	return {
		...batch,
		phase: batch.status === "cancelled" && isStillStopping ? "cancelling" : phaseOf(batch.status),
		items: (batch.items ?? []).map((item) => ({ ...item, phase: phaseOf(item.status) })),
	};
}
