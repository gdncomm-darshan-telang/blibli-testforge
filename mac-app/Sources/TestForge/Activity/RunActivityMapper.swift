import Foundation

/// Turns the `results` and `narration` slices into what the menu bar shows and what a finish notice says.
enum RunActivityMapper {
	private static let pendingCountKeys: Set<String> = ["QUEUED", "RUNNING", "SKIPPING", "—"]

	/// A batch's own cases narrate too; a run that started inside a batch's window belongs to it, not to the person.
	private static let batchGraceSeconds: TimeInterval = 5

	static func state(narration: NarrationState?, results: ResultsState?, lastResult: String?) -> RunActivityState {
		let runningRun = narration?.runs.first { $0.isRunning }
		let stepText = runningRun.flatMap { currentStepText(for: $0) }
		if let batch = results?.runs.first(where: { ResultsFormatting.isRunning(summary: $0) }) {
			let pendingCount = batch.counts.filter { pendingCountKeys.contains($0.key) }.values.reduce(0, +)
			let doneCount = batch.caseCount - pendingCount
			let branch = batch.branch ?? String(localized: "unknown branch")
			let isPaused = batch.status == "paused"
			let title = isPaused
				? String(localized: "Paused at \(doneCount) of \(batch.caseCount) · \(branch)")
				: String(localized: "Running \(doneCount) of \(batch.caseCount) done · \(branch)")
			let detail = runningRun?.title ?? ResultsFormatting.countsText(counts: batch.counts)
			let pauseReason = isPaused ? batch.pauseReason ?? String(localized: "Waiting for you to continue") : nil
			let progress = RunActivityProgress(title: title, detail: detail, stepText: stepText, stopTarget: .batch, pauseReason: pauseReason)
			return .running(progress)
		}
		if let runningRun {
			let title = String(localized: "Running \(runningRun.caseId ?? runningRun.title)")
			let progress = RunActivityProgress(title: title, detail: runningRun.title, stepText: stepText, stopTarget: .job(id: runningRun.id), pauseReason: nil)
			return .running(progress)
		}
		return .idle(lastResult: lastResult)
	}

	static func isPartOfBatch(run: NarratedRun, batches: [ResultRunSummary]) -> Bool {
		guard let startedAt = run.startedAt else {
			return false
		}
		return batches.contains { batch in
			guard let createdAt = batch.createdAt else {
				return false
			}
			let windowEnd = batch.endedAt?.addingTimeInterval(batchGraceSeconds) ?? .distantFuture
			return startedAt >= createdAt && startedAt <= windowEnd
		}
	}

	static func failingCount(summary: ResultRunSummary) -> Int {
		summary.counts.filter { ResultsFormatting.tone(for: $0.key) == .failed }.values.reduce(0, +)
	}

	static func batchNotice(summary: ResultRunSummary, failingCaseIds: [String]) -> FinishNotice {
		let branch = summary.branch ?? String(localized: "unknown branch")
		let title = summary.status == "done"
			? String(localized: "\(summary.caseCount) cases finished on \(branch)")
			: String(localized: "Run stopped on \(branch)")
		var body = ResultsFormatting.countsText(counts: summary.counts)
		if !failingCaseIds.isEmpty {
			body += " (\(failingCaseIds.joined(separator: ", ")))"
		}
		return FinishNotice(title: title, body: body)
	}

	static func singleNotice(run: NarratedRun) -> FinishNotice {
		let name = run.caseId ?? run.title
		let verdict = run.verdict ?? String(localized: "no verdict")
		return FinishNotice(title: String(localized: "\(name) finished"), body: verdict)
	}

	static func lastResultText(notice: FinishNotice) -> String {
		"\(notice.title): \(notice.body)"
	}

	private static func currentStepText(for run: NarratedRun) -> String? {
		guard let step = run.steps.last(where: { $0.status == "working" }) ?? run.steps.last else {
			return nil
		}
		return String(localized: "Step \(step.id): \(step.text)")
	}
}
