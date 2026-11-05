import Foundation

/// Turns the `results` slice and a run comparison into the Reports screen's ready-to-render models.
enum ReportsSectionMapper {
	/// The server files runs without a recorded branch under "unknown"; the run list must match it.
	static func branchName(of summary: ResultRunSummary) -> String {
		summary.branch ?? "unknown"
	}

	static func branchRows(from branches: [BranchHistoryEntry]) -> [BranchRowModel] {
		branches.map { entry in
			let latest = entry.latest
			let passedText = ResultsFormatting.passedText(summary: latest)
			let runTitle = ResultsFormatting.runTitle(summary: latest)
			let passedCount = latest.counts["PASS"] ?? 0
			let tone: VerdictTone = passedCount == latest.caseCount ? .passed : .failed
			return BranchRowModel(
				id: entry.branch,
				detail: "\(passedText) · \(runTitle)",
				runCountText: String(localized: "\(entry.runCount) runs"),
				tone: tone
			)
		}
	}

	static func runOptions(from summaries: [ResultRunSummary]) -> [ReportRunOption] {
		summaries.map { summary in
			let title = "\(ResultsFormatting.runTitle(summary: summary)) · \(ResultsFormatting.passedText(summary: summary))"
			return ReportRunOption(id: summary.id, title: title)
		}
	}

	static func baseOptions(from summaries: [ResultRunSummary]) -> [ReportRunOption] {
		summaries.map { summary in
			let title = "\(branchName(of: summary)) · \(ResultsFormatting.runTitle(summary: summary)) · \(ResultsFormatting.passedText(summary: summary))"
			return ReportRunOption(id: summary.id, title: title)
		}
	}

	static func comparison(from comparison: RunComparison) -> RunComparisonModel {
		guard let base = comparison.base else {
			let title = String(localized: "No earlier run shares these cases, so nothing to compare with yet.")
			return RunComparisonModel(title: title, chips: [], rows: [])
		}
		let title = String(localized: "Compared with \(ResultsFormatting.codeText(summary: base)) · \(ResultsFormatting.runTitle(summary: base))")
		let chips = [
			chip(id: "newlyFailing", title: String(localized: "newly failing"), count: comparison.counts["newlyFailing"], tone: .failed),
			chip(id: "fixed", title: String(localized: "fixed"), count: comparison.counts["fixed"], tone: .passed),
			chip(id: "same", title: String(localized: "unchanged"), count: comparison.counts["same"], tone: .notRun),
			chip(id: "added", title: String(localized: "not in the other run"), count: comparison.counts["added"], tone: .neutral),
			chip(id: "notRun", title: String(localized: "not run here"), count: comparison.counts["notRun"], tone: .neutral),
		].compactMap { $0 }
		let rows = comparison.rows
			.sorted { rank(of: $0.change) < rank(of: $1.change) }
			.map { row(from: $0) }
		return RunComparisonModel(title: title, chips: chips, rows: rows)
	}

	static func preview(for summary: ResultRunSummary, comparison: RunComparison?) -> ReportPreviewModel {
		var facts = [
			ResultFactModel(id: "code", label: String(localized: "Code"), value: ResultsFormatting.codeText(summary: summary)),
			ResultFactModel(id: "tests", label: String(localized: "Tests"), value: ResultsFormatting.countsText(counts: summary.counts)),
			ResultFactModel(id: "review", label: String(localized: "Review"), value: ResultsFormatting.reviewText(summary: summary)),
		]
		if let simulator = summary.simulator {
			facts.append(ResultFactModel(id: "simulator", label: String(localized: "Phone"), value: simulator))
		}
		if let environment = summary.environment {
			facts.append(ResultFactModel(id: "environment", label: String(localized: "Server"), value: environment))
		}
		if let base = comparison?.base,
			let counts = comparison?.counts {
			let newlyFailing = counts["newlyFailing"] ?? 0
			let fixed = counts["fixed"] ?? 0
			let text = String(localized: "\(ResultsFormatting.codeText(summary: base)) — \(newlyFailing) newly failing, \(fixed) fixed")
			facts.append(ResultFactModel(id: "compared", label: String(localized: "Compared"), value: text))
		}
		if summary.isUnverified {
			facts.append(ResultFactModel(id: "build", label: String(localized: "Build"), value: String(localized: "Unverified build")))
		}
		let title = String(localized: "QA run — \(ResultsFormatting.runTitle(summary: summary))")
		return ReportPreviewModel(title: title, facts: facts)
	}

	private static func chip(id: String, title: String, count: Int?, tone: VerdictTone) -> ComparisonChipModel? {
		guard let count,
			count > 0
		else {
			return nil
		}
		return ComparisonChipModel(id: id, title: "\(count) \(title)", tone: tone)
	}

	private static func rank(of change: ComparisonChange) -> Int {
		switch change {
			case .newlyFailing:
				return 0
			case .fixed:
				return 1
			case .added:
				return 2
			case .notRun:
				return 3
			case .same:
				return 4
		}
	}

	private static func row(from row: ComparisonRow) -> ComparisonRowModel {
		let changeText: String
		let changeTone: VerdictTone
		switch row.change {
			case .newlyFailing:
				changeText = String(localized: "Newly failing")
				changeTone = .failed
			case .fixed:
				changeText = String(localized: "Fixed")
				changeTone = .passed
			case .same:
				changeText = String(localized: "Same")
				changeTone = .notRun
			case .added:
				changeText = String(localized: "New here")
				changeTone = .neutral
			case .notRun:
				changeText = String(localized: "Not run here")
				changeTone = .neutral
		}
		return ComparisonRowModel(
			id: row.caseId,
			scenario: row.scenario,
			baseText: row.baseVerdict ?? "—",
			headText: row.headVerdict ?? "—",
			changeText: changeText,
			changeTone: changeTone
		)
	}
}
