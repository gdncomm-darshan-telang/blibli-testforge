import Foundation

enum TrackerRowVerdict: Equatable {
	case fired
	case firedWithProblems
	case rejected
	case notFired
}

struct TrackerRowModel: Identifiable, Equatable {
	let id: String
	let verdict: TrackerRowVerdict
	let countText: String
	let eventText: String
	let screenText: String
	let problems: [String]
}

struct TrackerFireModel: Identifiable, Equatable {
	let id: String
	let title: String
	let detailText: String
	let problems: [String]
	let payload: String
}

/// The Trackers tab's ready-to-render answer: rows plus the two lists a sign-off cares about.
struct TrackersDisplayModel: Equatable {
	let headline: String
	let rows: [TrackerRowModel]
	let unexpectedText: String?
	let contractWarning: String?
}

/// `/api/lens/trackers*` answers → Trackers tab display models (D-129). Raw numbers only.
enum NetworkTrackerMapper {
	static func display(_ answer: LensTrackersResponse, isExpectedList: Bool) -> TrackersDisplayModel {
		let rows = answer.rows.map(row)
		let firedCount = rows.filter { $0.verdict != .notFired }.count
		let problemCount = rows.filter { $0.verdict == .firedWithProblems }.count
		let headline = isExpectedList
			? String(localized: "\(firedCount) of \(rows.count) fired · \(answer.missing.count) missing · \(problemCount) with payload problems")
			: String(localized: "\(rows.count) TRMS IDs fired in this launch")
		let unexpectedText = answer.unexpected.isEmpty
			? nil
			: String(localized: "Also fired, not on the list: \(answer.unexpected.joined(separator: ", "))")
		let contractWarning = answer.contractIdsNotListed.isEmpty
			? nil
			: String(localized: "Contract has IDs not on the list (typo?): \(answer.contractIdsNotListed.joined(separator: ", "))")
		return TrackersDisplayModel(headline: headline, rows: rows, unexpectedText: unexpectedText, contractWarning: contractWarning)
	}

	static func fires(_ detail: LensTrackerDetail) -> [TrackerFireModel] {
		detail.fires.enumerated().map { index, fire in
			let statusText = fire.status.map(String.init) ?? "—"
			let title = "\(fire.event ?? "—") · \(statusText) · \(fire.startedAt ?? "")"
			let detailText = "\(fire.originScreen ?? "—") · \(fire.endpoint ?? "—")"
			return TrackerFireModel(
				id: "\(fire.exchangeId)-\(index)",
				title: title,
				detailText: detailText,
				problems: fire.problems,
				payload: fire.payload
			)
		}
	}

	/// IDs typed with commas, spaces or new lines; order kept, repeats dropped.
	static func ids(from text: String) -> [String] {
		let separators = CharacterSet(charactersIn: ",;").union(.whitespacesAndNewlines)
		var seen = Set<String>()
		return text.components(separatedBy: separators)
			.filter { !$0.isEmpty }
			.filter { seen.insert($0).inserted }
	}

	private static func row(_ row: LensTrackerRow) -> TrackerRowModel {
		let verdict = verdict(for: row)
		let countText: String
		switch verdict {
			case .notFired:
				countText = String(localized: "not fired")
			case .rejected:
				countText = "\(row.fireCount)× (\(row.rejected) non-2xx)"
			case .fired, .firedWithProblems:
				countText = "\(row.fireCount)×"
		}
		return TrackerRowModel(
			id: row.id,
			verdict: verdict,
			countText: countText,
			eventText: row.event ?? "—",
			screenText: row.originScreen ?? "—",
			problems: row.problems
		)
	}

	/// A non-2xx fire did not land at the collector, so it outranks payload problems.
	private static func verdict(for row: LensTrackerRow) -> TrackerRowVerdict {
		if row.fireCount < 1 {
			return .notFired
		}
		if row.rejected > 0 {
			return .rejected
		}
		return row.problems.isEmpty ? .fired : .firedWithProblems
	}
}
