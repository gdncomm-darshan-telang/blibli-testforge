import Foundation

/// The `results` slice (D-087): every kept run, newest first, and the newest run per branch.
struct ResultsState: Decodable, Equatable {
	let runs: [ResultRunSummary]
	let branches: [BranchHistoryEntry]

	private enum CodingKeys: String, CodingKey {
		case runs
		case branches
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		runs = (try? container.decodeIfPresent([ResultRunSummary].self, forKey: .runs)) ?? []
		branches = (try? container.decodeIfPresent([BranchHistoryEntry].self, forKey: .branches)) ?? []
	}
}

struct ResultRunSummary: Decodable, Equatable, Identifiable {
	let id: String
	let createdAt: Date?
	let endedAt: Date?

	/// Raw server stamp; it moves on every change to the run, which is when its detail is fetched again.
	let updatedAt: String

	let status: String
	let rerunOf: String?
	let caseCount: Int
	let caseIds: [String]
	let counts: [String: Int]
	let reviewedCount: Int
	let isValidated: Bool
	let branch: String?
	let codeId: String?
	let hasLocalChanges: Bool

	/// The run tested an installed app that did not match the prepared code; the report flags it.
	let isUnverified: Bool

	let simulator: String?
	let environment: String?

	/// Why a paused batch is holding (a crash, or Claude's usage limit); nil unless paused.
	let pauseReason: String?

	/// Set when the run replayed an imported bundle (D-162); its cases then carry the bundle's verdicts.
	let bundleId: String?

	private enum CodingKeys: String, CodingKey {
		case id
		case createdAt
		case endedAt
		case updatedAt
		case status
		case rerunOf
		case caseCount = "cases"
		case caseIds
		case counts
		case reviewedCount = "reviewed"
		case isValidated
		case branch
		case codeId
		case hasLocalChanges
		case isUnverified
		case simulator
		case environment
		case pauseReason
		case bundleId
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? ""
		let createdText = try? container.decodeIfPresent(String.self, forKey: .createdAt)
		createdAt = createdText.flatMap { ServerDate.parse(text: $0) }
		let endedText = try? container.decodeIfPresent(String.self, forKey: .endedAt)
		endedAt = endedText.flatMap { ServerDate.parse(text: $0) }
		updatedAt = (try? container.decodeIfPresent(String.self, forKey: .updatedAt)) ?? ""
		status = (try? container.decodeIfPresent(String.self, forKey: .status)) ?? ""
		rerunOf = try? container.decodeIfPresent(String.self, forKey: .rerunOf)
		caseCount = (try? container.decodeIfPresent(Int.self, forKey: .caseCount)) ?? 0
		caseIds = (try? container.decodeIfPresent([String].self, forKey: .caseIds)) ?? []
		counts = (try? container.decodeIfPresent([String: Int].self, forKey: .counts)) ?? [:]
		reviewedCount = (try? container.decodeIfPresent(Int.self, forKey: .reviewedCount)) ?? 0
		isValidated = (try? container.decodeIfPresent(Bool.self, forKey: .isValidated)) ?? false
		branch = try? container.decodeIfPresent(String.self, forKey: .branch)
		codeId = try? container.decodeIfPresent(String.self, forKey: .codeId)
		hasLocalChanges = (try? container.decodeIfPresent(Bool.self, forKey: .hasLocalChanges)) ?? false
		isUnverified = (try? container.decodeIfPresent(Bool.self, forKey: .isUnverified)) ?? false
		simulator = try? container.decodeIfPresent(String.self, forKey: .simulator)
		environment = try? container.decodeIfPresent(String.self, forKey: .environment)
		pauseReason = try? container.decodeIfPresent(String.self, forKey: .pauseReason)
		bundleId = try? container.decodeIfPresent(String.self, forKey: .bundleId)
	}
}

struct BranchHistoryEntry: Decodable, Equatable, Identifiable {
	let branch: String
	let runCount: Int
	let latest: ResultRunSummary

	var id: String { branch }

	private enum CodingKeys: String, CodingKey {
		case branch
		case runCount
		case latest
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		branch = (try? container.decodeIfPresent(String.self, forKey: .branch)) ?? ""
		runCount = (try? container.decodeIfPresent(Int.self, forKey: .runCount)) ?? 0
		latest = try container.decode(ResultRunSummary.self, forKey: .latest)
	}
}

/// `GET /api/results/:id` — only the cases are read; the summary comes from the slice.
struct ResultRunResponse: Decodable {
	let items: [ResultItem]

	private enum CodingKeys: String, CodingKey {
		case run
	}

	private enum RunKeys: String, CodingKey {
		case items
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let run = try container.nestedContainer(keyedBy: RunKeys.self, forKey: .run)
		items = (try? run.decodeIfPresent([ResultItem].self, forKey: .items)) ?? []
	}
}

struct ResultItem: Decodable, Equatable {
	let caseId: String
	let scenario: String
	let mode: String
	let macroName: String?
	let status: String
	let verdict: String?
	let finalVerdict: String
	let durationMs: Double?
	let review: ResultReview?
	let rerunVerdict: String?
	let evidence: ResultEvidence?
	let triage: ResultTriage?
	let crash: ResultCrash?
	let learned: ResultLearned?
	let isRepaired: Bool
	let verdictBeforeRepair: String?

	/// The verdict the bundle's own run gave this case; nil outside a bundle replay.
	let bundleVerdict: String?

	private enum CodingKeys: String, CodingKey {
		case caseId
		case scenario
		case mode
		case macroName
		case status
		case verdict
		case finalVerdict
		case durationMs
		case review
		case rerun
		case evidence
		case triage
		case crash
		case learned
		case isRepaired = "repaired"
		case verdictBeforeRepair
		case bundleVerdict
	}

	private enum RerunKeys: String, CodingKey {
		case verdict
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		caseId = (try? container.decodeIfPresent(String.self, forKey: .caseId)) ?? ""
		scenario = (try? container.decodeIfPresent(String.self, forKey: .scenario)) ?? ""
		mode = (try? container.decodeIfPresent(String.self, forKey: .mode)) ?? ""
		macroName = try? container.decodeIfPresent(String.self, forKey: .macroName)
		status = (try? container.decodeIfPresent(String.self, forKey: .status)) ?? ""
		verdict = try? container.decodeIfPresent(String.self, forKey: .verdict)
		finalVerdict = (try? container.decodeIfPresent(String.self, forKey: .finalVerdict)) ?? "—"
		durationMs = try? container.decodeIfPresent(Double.self, forKey: .durationMs)
		review = try? container.decodeIfPresent(ResultReview.self, forKey: .review)
		let rerun = try? container.nestedContainer(keyedBy: RerunKeys.self, forKey: .rerun)
		rerunVerdict = try? rerun?.decodeIfPresent(String.self, forKey: .verdict)
		evidence = try? container.decodeIfPresent(ResultEvidence.self, forKey: .evidence)
		triage = try? container.decodeIfPresent(ResultTriage.self, forKey: .triage)
		crash = try? container.decodeIfPresent(ResultCrash.self, forKey: .crash)
		learned = try? container.decodeIfPresent(ResultLearned.self, forKey: .learned)
		isRepaired = (try? container.decodeIfPresent(Bool.self, forKey: .isRepaired)) ?? false
		verdictBeforeRepair = try? container.decodeIfPresent(String.self, forKey: .verdictBeforeRepair)
		bundleVerdict = try? container.decodeIfPresent(String.self, forKey: .bundleVerdict)
	}
}

struct ResultReview: Decodable, Equatable {
	let action: String
	let verdict: String?
	let reason: String?

	private enum CodingKeys: String, CodingKey {
		case action
		case verdict
		case reason
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		action = (try? container.decodeIfPresent(String.self, forKey: .action)) ?? ""
		verdict = try? container.decodeIfPresent(String.self, forKey: .verdict)
		reason = try? container.decodeIfPresent(String.self, forKey: .reason)
	}
}

struct ResultEvidence: Decodable, Equatable {
	let screenshotPaths: [String]
	let videoPaths: [String]
	let mocksServed: [String: Int]

	/// D-163: which variant answered, per endpoint; empty for runs recorded before it.
	let mocksUsed: [BundleCaseMock]
	let steps: [String]
	let summary: String?
	let costUsd: Double?
	let folderPath: String?

	private enum CodingKeys: String, CodingKey {
		case screenshotPaths = "screenshots"
		case videoPaths = "videos"
		case mocksServed
		case mocksUsed
		case steps
		case summary
		case costUsd
		case folderPath = "folder"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		screenshotPaths = (try? container.decodeIfPresent([String].self, forKey: .screenshotPaths)) ?? []
		videoPaths = (try? container.decodeIfPresent([String].self, forKey: .videoPaths)) ?? []
		mocksServed = (try? container.decodeIfPresent([String: Int].self, forKey: .mocksServed)) ?? [:]
		mocksUsed = (try? container.decodeIfPresent([BundleCaseMock].self, forKey: .mocksUsed)) ?? []
		steps = (try? container.decodeIfPresent([String].self, forKey: .steps)) ?? []
		summary = try? container.decodeIfPresent(String.self, forKey: .summary)
		costUsd = try? container.decodeIfPresent(Double.self, forKey: .costUsd)
		folderPath = try? container.decodeIfPresent(String.self, forKey: .folderPath)
	}
}

struct ResultTriage: Decodable, Equatable {
	let kind: String
	let summary: String

	private enum CodingKeys: String, CodingKey {
		case kind
		case summary
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		kind = (try? container.decodeIfPresent(String.self, forKey: .kind)) ?? ""
		summary = (try? container.decodeIfPresent(String.self, forKey: .summary)) ?? ""
	}
}

struct ResultCrash: Decodable, Equatable {
	let exception: String?
	let path: String?

	private enum CodingKeys: String, CodingKey {
		case exception
		case path
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		exception = try? container.decodeIfPresent(String.self, forKey: .exception)
		path = try? container.decodeIfPresent(String.self, forKey: .path)
	}
}

struct ResultLearned: Decodable, Equatable {
	let isSaved: Bool
	let macroName: String?
	let reason: String?

	private enum CodingKeys: String, CodingKey {
		case isSaved = "ok"
		case macroName
		case reason
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		isSaved = (try? container.decodeIfPresent(Bool.self, forKey: .isSaved)) ?? false
		macroName = try? container.decodeIfPresent(String.self, forKey: .macroName)
		reason = try? container.decodeIfPresent(String.self, forKey: .reason)
	}
}

enum ComparisonChange: String, Decodable, Equatable {
	case newlyFailing
	case fixed
	case same
	case added
	case notRun
}

/// `GET /api/results/:id/compare` — per case, the other run's final verdict next to this run's.
struct RunComparison: Decodable, Equatable {
	let base: ResultRunSummary?
	let head: ResultRunSummary
	let rows: [ComparisonRow]
	let counts: [String: Int]

	private enum CodingKeys: String, CodingKey {
		case base
		case head
		case rows
		case counts
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		base = try? container.decodeIfPresent(ResultRunSummary.self, forKey: .base)
		head = try container.decode(ResultRunSummary.self, forKey: .head)
		rows = (try? container.decodeIfPresent([ComparisonRow].self, forKey: .rows)) ?? []
		counts = (try? container.decodeIfPresent([String: Int].self, forKey: .counts)) ?? [:]
	}
}

struct ComparisonRow: Decodable, Equatable {
	let caseId: String
	let scenario: String
	let baseVerdict: String?
	let headVerdict: String?
	let change: ComparisonChange

	private enum CodingKeys: String, CodingKey {
		case caseId
		case scenario
		case baseVerdict = "base"
		case headVerdict = "head"
		case change
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		caseId = (try? container.decodeIfPresent(String.self, forKey: .caseId)) ?? ""
		scenario = (try? container.decodeIfPresent(String.self, forKey: .scenario)) ?? ""
		baseVerdict = try? container.decodeIfPresent(String.self, forKey: .baseVerdict)
		headVerdict = try? container.decodeIfPresent(String.self, forKey: .headVerdict)
		change = (try? container.decodeIfPresent(ComparisonChange.self, forKey: .change)) ?? .same
	}
}
