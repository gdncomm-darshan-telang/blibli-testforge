import Foundation

/// Turns the `results` slice and a run's cases into the Results screen's ready-to-render models.
enum ResultsSectionMapper {
	static func runRows(from summaries: [ResultRunSummary]) -> [ResultRunRowModel] {
		summaries.map { summary in
			let rerunText = summary.rerunOf == nil ? "" : String(localized: " · re-run")
			return ResultRunRowModel(
				id: summary.id,
				title: ResultsFormatting.runTitle(summary: summary) + rerunText,
				subtitle: ResultsFormatting.codeText(summary: summary),
				countsText: ResultsFormatting.countsText(counts: summary.counts),
				reviewText: ResultsFormatting.reviewText(summary: summary),
				isValidated: summary.isValidated,
				isRunning: ResultsFormatting.isRunning(summary: summary)
			)
		}
	}

	/// Re-run failed picks failures and cases marked Needs re-run, so either enables it.
	static func header(for summary: ResultRunSummary, items: [ResultItem]) -> ResultRunHeaderModel {
		let isRunning = ResultsFormatting.isRunning(summary: summary)
		let hasFailures = summary.counts.keys.contains { ResultsFormatting.tone(for: $0) != .passed }
		let hasRerunMarks = items.contains { $0.review?.action == "rerun" }
		let warning = summary.isUnverified ? String(localized: "Unverified build: the installed app did not match the prepared code.") : nil
		return ResultRunHeaderModel(
			title: ResultsFormatting.runTitle(summary: summary),
			facts: facts(for: summary, items: items),
			warning: warning,
			tiles: tiles(for: summary),
			reviewText: ResultsFormatting.reviewText(summary: summary),
			isValidated: summary.isValidated,
			canRerunFailed: (hasFailures || hasRerunMarks) && !isRunning
		)
	}

	static func caseRows(from items: [ResultItem]) -> [ResultCaseRowModel] {
		items.enumerated().map { index, item in
			ResultCaseRowModel(
				id: index,
				caseId: item.caseId,
				scenario: item.scenario,
				ranAsText: ranAsText(for: item),
				verdictText: item.finalVerdict,
				verdictTone: ResultsFormatting.tone(for: item.finalVerdict),
				reviewText: reviewText(for: item.review),
				isReviewed: isReviewed(review: item.review),
				proofLocationURL: proofLocationURL(for: item.evidence, caseId: item.caseId)
			)
		}
	}

	/// The case's own folder when it has one; otherwise its first proof file, which sits in a folder shared with other cases.
	static func proofLocationURL(for evidence: ResultEvidence?, caseId: String) -> URL? {
		if let folderPath = evidence?.folderPath {
			return URL(fileURLWithPath: folderPath, isDirectory: true)
		}
		guard let firstProofPath = evidence?.screenshotPaths.first ?? evidence?.videoPaths.first else {
			return nil
		}
		let fileURL = URL(fileURLWithPath: firstProofPath)
		let folderURL = fileURL.deletingLastPathComponent()
		let caseFolderName = caseId.replacingOccurrences(of: "[^A-Za-z0-9_.-]", with: "_", options: .regularExpression)
		return folderURL.lastPathComponent == caseFolderName ? folderURL : fileURL
	}

	static func caseDetail(for item: ResultItem, index: Int) -> ResultCaseDetailModel {
		let evidence = item.evidence
		let mocks = mockLines(for: evidence)
		let screenshotURLs = (evidence?.screenshotPaths ?? []).map { URL(fileURLWithPath: $0) }
		let videoURLs = (evidence?.videoPaths ?? []).map { URL(fileURLWithPath: $0) }
		let summary = evidence?.summary?.trimmingCharacters(in: .whitespacesAndNewlines)
		let proofLocationURL = proofLocationURL(for: evidence, caseId: item.caseId)
		return ResultCaseDetailModel(
			index: index,
			caseId: item.caseId,
			scenario: item.scenario,
			verdictText: item.finalVerdict,
			verdictTone: ResultsFormatting.tone(for: item.finalVerdict),
			historyText: historyText(for: item),
			reviewText: reviewText(for: item.review),
			notes: notes(for: item),
			mocks: mocks,
			screenshotURLs: screenshotURLs,
			videoURLs: videoURLs,
			proofLocationURL: proofLocationURL,
			summary: summary?.isEmpty == true ? nil : summary,
			steps: evidence?.steps ?? []
		)
	}

	/// "12 of 14 agree with the bundle": a replay passing where the bundle passed, or failing where it didn't.
	private static func bundleAgreementText(items: [ResultItem]) -> String? {
		let compared = items.filter { $0.bundleVerdict != nil && $0.status == "done" }
		guard !compared.isEmpty else {
			return nil
		}
		let agreeing = compared.filter { item in
			let isBundlePass = item.bundleVerdict?.hasPrefix("PASS") ?? false
			return item.finalVerdict.hasPrefix("PASS") == isBundlePass
		}
		return String(localized: "\(agreeing.count) of \(compared.count) replayed cases agree with the bundle's run")
	}

	/// Variant names when the run recorded them (D-163), else endpoint counts.
	private static func mockLines(for evidence: ResultEvidence?) -> [String] {
		guard let evidence else {
			return []
		}
		guard evidence.mocksUsed.isEmpty else {
			return evidence.mocksUsed.map { mock in
				let variantText = mock.variant ?? (mock.candidates.isEmpty ? String(localized: "unknown response") : mock.candidates.joined(separator: " or "))
				return "\(mock.endpoint) → \(variantText)"
			}
		}
		return evidence.mocksServed
			.sorted { $0.key < $1.key }
			.map { "\($0.key) ×\($0.value)" }
	}

	private static func facts(for summary: ResultRunSummary, items: [ResultItem]) -> [ResultFactModel] {
		var facts = [ResultFactModel(id: "code", label: String(localized: "Code"), value: ResultsFormatting.codeText(summary: summary))]
		if let agreementText = bundleAgreementText(items: items) {
			facts.append(ResultFactModel(id: "bundle", label: String(localized: "Bundle"), value: agreementText))
		}
		if let simulator = summary.simulator {
			facts.append(ResultFactModel(id: "simulator", label: String(localized: "Simulator"), value: simulator))
		}
		if let environment = summary.environment {
			facts.append(ResultFactModel(id: "environment", label: String(localized: "Server"), value: environment))
		}
		if let endedAt = summary.endedAt,
			let createdAt = summary.createdAt {
			let milliseconds = endedAt.timeIntervalSince(createdAt) * 1000
			let durationText = ResultsFormatting.durationText(milliseconds: milliseconds)
			facts.append(ResultFactModel(id: "duration", label: String(localized: "Took"), value: durationText))
		}
		return facts
	}

	private static func tiles(for summary: ResultRunSummary) -> [ResultTileModel] {
		let passedCount = summary.counts["PASS"] ?? 0
		let failingCount = summary.counts.filter { ResultsFormatting.tone(for: $0.key) == .failed }.values.reduce(0, +)
		let otherCount = summary.caseCount - passedCount - failingCount
		return [
			ResultTileModel(id: "cases", title: String(localized: "Cases"), value: "\(summary.caseCount)", tone: .notRun),
			ResultTileModel(id: "passed", title: String(localized: "Passed"), value: "\(passedCount)", tone: .passed),
			ResultTileModel(id: "failed", title: String(localized: "Failed"), value: "\(failingCount)", tone: .failed),
			ResultTileModel(id: "other", title: String(localized: "Flaky or open"), value: "\(otherCount)", tone: .neutral),
		]
	}

	private static func ranAsText(for item: ResultItem) -> String {
		guard item.mode == "replay" else {
			return String(localized: "Claude")
		}
		let recordingText = item.macroName.map { String(localized: "Recording · \($0)") } ?? String(localized: "Recording")
		guard let bundleVerdict = item.bundleVerdict else {
			return recordingText
		}
		return String(localized: "Bundle said \(bundleVerdict) · ") + recordingText
	}

	private static func historyText(for item: ResultItem) -> String {
		var parts = [String(localized: "Run: \(item.verdict ?? item.status)")]
		if let rerunVerdict = item.rerunVerdict {
			parts.append(String(localized: "re-run: \(rerunVerdict)"))
		}
		if let durationMs = item.durationMs {
			let durationText = ResultsFormatting.durationText(milliseconds: durationMs)
			parts.append(durationText)
		}
		if let costUsd = item.evidence?.costUsd {
			let costText = costUsd.formatted(.currency(code: "USD"))
			parts.append(String(localized: "Claude \(costText)"))
		}
		return parts.joined(separator: " · ")
	}

	private static func isReviewed(review: ResultReview?) -> Bool {
		["accept", "override"].contains(review?.action ?? "")
	}

	private static func reviewText(for review: ResultReview?) -> String {
		guard let review else {
			return String(localized: "Not reviewed")
		}
		switch review.action {
			case "accept":
				return String(localized: "Accepted")
			case "override":
				let verdict = review.verdict ?? ""
				let reason = review.reason.map { ": \($0)" } ?? ""
				return String(localized: "Overridden to \(verdict)\(reason)")
			case "rerun":
				return String(localized: "Needs re-run")
			default:
				return review.action
		}
	}

	private static func notes(for item: ResultItem) -> [ResultNoteModel] {
		var notes: [ResultNoteModel] = []
		if let triage = item.triage {
			notes.append(ResultNoteModel(id: "triage", symbolName: "stethoscope", title: String(localized: "Claude's triage · \(triage.kind)"), text: triage.summary))
		}
		if item.isRepaired {
			let before = item.verdictBeforeRepair ?? "—"
			let text = String(localized: "Claude repaired the recording; the driver replayed it. Before the repair: \(before)")
			notes.append(ResultNoteModel(id: "repaired", symbolName: "wrench.and.screwdriver", title: String(localized: "Recording repaired"), text: text))
		}
		if let learned = item.learned {
			let text = learned.isSaved
				? String(localized: "Saved as “\(learned.macroName ?? "")” — its replay passed.")
				: String(localized: "Not saved: \(learned.reason ?? "the replay did not pass")")
			notes.append(ResultNoteModel(id: "learned", symbolName: "record.circle", title: String(localized: "Recording"), text: text))
		}
		if let crash = item.crash {
			let fileName = crash.path.map { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
			let text = [crash.exception, fileName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
			notes.append(ResultNoteModel(id: "crash", symbolName: "exclamationmark.octagon", title: String(localized: "App crashed"), text: text))
		}
		return notes
	}
}
