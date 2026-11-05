import Foundation

/// Turns Test Batch summaries into the Batches list and detail header, so views never count or format.
enum BatchReportsMapper {
	static func row(for batch: TestBatchSummary) -> BatchReportRowModel {
		BatchReportRowModel(
			id: batch.id,
			name: batch.name,
			dateText: dateText(for: batch),
			progressText: progressText(for: batch.progress),
			status: batch.status,
			hasFailures: batch.progress.failed > 0
		)
	}

	static func detail(for batch: TestBatchSummary) -> BatchReportDetailModel {
		BatchReportDetailModel(
			id: batch.id,
			name: batch.name,
			statusText: statusText(for: batch),
			progressText: progressText(for: batch.progress),
			folderText: batch.folder,
			status: batch.status,
			comparisonText: batch.comparison.map { comparisonText(for: $0) },
			hasRegressions: (batch.comparison?.regressed ?? 0) > 0,
			canReplay: batch.status == .ended && batch.progress.caseCount > 0
		)
	}

	static func comparisonText(for comparison: TestBatchComparison) -> String {
		var parts = [String(localized: "\(comparison.regressed) regressed"), String(localized: "\(comparison.fixed) fixed"), String(localized: "\(comparison.same) same")]
		if comparison.missing > 0 {
			parts.append(String(localized: "\(comparison.missing) waiting"))
		}
		return String(localized: "Against “\(comparison.sourceName)”: \(parts.joined(separator: " · "))")
	}

	static func replayNotice(for started: TestBatchReplayStart) -> String {
		let skipped = started.skippedCount > 0 ? String(localized: " \(started.skippedCount) case(s) have no recording and were left out.") : ""
		return String(localized: "Replaying \(started.caseCount) case(s) on the installed build, driver only.\(skipped)")
	}

	static func progressText(for progress: TestBatchProgress) -> String {
		guard progress.caseCount > 0 || progress.running > 0 else {
			return String(localized: "No test results yet")
		}
		var parts = [String(localized: "\(progress.caseCount) cases"), String(localized: "\(progress.passed) passed")]
		if progress.failed > 0 {
			parts.append(String(localized: "\(progress.failed) failed"))
		}
		if progress.undecided > 0 {
			parts.append(String(localized: "\(progress.undecided) undecided"))
		}
		if progress.running > 0 {
			parts.append(String(localized: "\(progress.running) running"))
		}
		return parts.joined(separator: " · ")
	}

	private static func statusText(for batch: TestBatchSummary) -> String {
		let dates = dateText(for: batch)
		switch batch.status {
			case .active:
				return String(localized: "Active · \(dates)")
			case .paused:
				let pausedText = batch.pausedAt?.formatted(date: .abbreviated, time: .shortened) ?? ""
				return String(localized: "Paused since \(pausedText) · started \(dates)")
			case .ended:
				return String(localized: "Ended · \(dates)")
		}
	}

	private static func dateText(for batch: TestBatchSummary) -> String {
		let started = batch.startedAt?.formatted(date: .abbreviated, time: .shortened) ?? ""
		guard let endedAt = batch.endedAt else {
			return started
		}
		return "\(started) – \(endedAt.formatted(date: .omitted, time: .shortened))"
	}
}

/// A batch button's text, idle and while that button's work runs.
struct BatchReportActionLabelText {
	let title: String
	let busyTitle: String
	let systemImage: String

	init(action: BatchReportAction) {
		switch action {
			case .refresh:
				self.init(title: String(localized: "Refresh"), busyTitle: String(localized: "Refreshing…"), systemImage: "arrow.clockwise")
			case .pause:
				self.init(title: String(localized: "Pause"), busyTitle: String(localized: "Pausing…"), systemImage: "pause.circle")
			case .resume:
				self.init(title: String(localized: "Resume"), busyTitle: String(localized: "Resuming…"), systemImage: "play.circle")
			case .end:
				self.init(title: String(localized: "End"), busyTitle: String(localized: "Ending…"), systemImage: "stop.circle")
			case .reopen:
				self.init(
					title: String(localized: "Reopen"),
					busyTitle: String(localized: "Reopening…"),
					systemImage: "arrow.uturn.backward.circle"
				)
			case .replay:
				self.init(
					title: String(localized: "Replay on this build"),
					busyTitle: String(localized: "Starting replay…"),
					systemImage: "arrow.triangle.2.circlepath"
				)
			case .remove:
				self.init(title: String(localized: "Remove"), busyTitle: String(localized: "Removing…"), systemImage: "trash")
		}
	}

	private init(title: String, busyTitle: String, systemImage: String) {
		self.title = title
		self.busyTitle = busyTitle
		self.systemImage = systemImage
	}
}
