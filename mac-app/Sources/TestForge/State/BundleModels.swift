import Foundation

/// `POST /api/bundles/inspect` and `/api/bundles/import` — the bundle and what importing does (did) here.
struct BundlePreview: Decodable, Equatable {
	let bundle: BundleSummary
	let plan: BundlePlan

	/// Only after an import: whether its cases joined the loaded document or became it (D-181).
	let caseImport: BundleCaseImport?

	private enum CodingKeys: String, CodingKey {
		case bundle
		case plan
		case caseImport = "cases"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		bundle = try container.decode(BundleSummary.self, forKey: .bundle)
		plan = try container.decode(BundlePlan.self, forKey: .plan)
		caseImport = try? container.decodeIfPresent(BundleCaseImport.self, forKey: .caseImport)
	}
}

/// D-181: a bundle of the loaded document adds its missing cases; any other bundle loads as the document.
struct BundleCaseImport: Decodable, Equatable {
	let isMerged: Bool
	let addedCount: Int

	private enum CodingKeys: String, CodingKey {
		case mode
		case added
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		isMerged = (try? container.decodeIfPresent(String.self, forKey: .mode)) == "merged"
		addedCount = ((try? container.decodeIfPresent([String].self, forKey: .added)) ?? []).count
	}
}

struct BundleSummary: Decodable, Equatable {
	let id: String
	let title: String
	let caseCount: Int
	let replayableCount: Int
	let costUsd: Double?
	let branch: String?
	let commit: String?
	let hasLocalChanges: Bool

	private enum CodingKeys: String, CodingKey {
		case id
		case title
		case caseCount = "cases"
		case replayableCount = "replayable"
		case costUsd
		case code
	}

	private enum CodeKeys: String, CodingKey {
		case branch
		case commit
		case hasLocalChanges
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? ""
		title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? ""
		caseCount = (try? container.decodeIfPresent(Int.self, forKey: .caseCount)) ?? 0
		replayableCount = (try? container.decodeIfPresent(Int.self, forKey: .replayableCount)) ?? 0
		costUsd = try? container.decodeIfPresent(Double.self, forKey: .costUsd)
		let code = try? container.nestedContainer(keyedBy: CodeKeys.self, forKey: .code)
		branch = try? code?.decodeIfPresent(String.self, forKey: .branch)
		commit = try? code?.decodeIfPresent(String.self, forKey: .commit)
		hasLocalChanges = (try? code?.decodeIfPresent(Bool.self, forKey: .hasLocalChanges)) ?? false
	}
}

/// `match` is the only code state where a replay tests the same app the bundle's run did.
enum BundleCodeState: String, Equatable {
	case match
	case notPrepared
	case otherBranch
	case otherCommit
	case localChanges
	case unknown
}

struct BundlePlan: Decodable, Equatable {
	let codeState: BundleCodeState
	let codeMessage: String
	let provenCount: Int
	let needsJudgmentCount: Int
	let credentials: [String]
	let conflictCount: Int
	let warnings: [String]
	let addedMacroCount: Int
	let addedElementCount: Int
	let addedMockCount: Int
	let written: BundleWritten?
	let caseMocks: [BundleCaseMocks]

	private enum CodingKeys: String, CodingKey {
		case code
		case counts
		case credentials
		case conflictCount = "conflicts"
		case warnings
		case macros
		case elements
		case mocks
		case written
		case caseMocks
	}

	private enum CodeKeys: String, CodingKey {
		case state
		case message
	}

	private enum CountKeys: String, CodingKey {
		case proven
		case needsJudgment
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let code = try? container.nestedContainer(keyedBy: CodeKeys.self, forKey: .code)
		let stateText = (try? code?.decodeIfPresent(String.self, forKey: .state)) ?? ""
		codeState = BundleCodeState(rawValue: stateText) ?? .unknown
		codeMessage = (try? code?.decodeIfPresent(String.self, forKey: .message)) ?? ""
		let counts = try? container.nestedContainer(keyedBy: CountKeys.self, forKey: .counts)
		provenCount = (try? counts?.decodeIfPresent(Int.self, forKey: .proven)) ?? 0
		needsJudgmentCount = (try? counts?.decodeIfPresent(Int.self, forKey: .needsJudgment)) ?? 0
		credentials = (try? container.decodeIfPresent([String].self, forKey: .credentials)) ?? []
		conflictCount = (try? container.decodeIfPresent(Int.self, forKey: .conflictCount)) ?? 0
		warnings = (try? container.decodeIfPresent([String].self, forKey: .warnings)) ?? []
		addedMacroCount = Self.addCount(in: container, forKey: .macros)
		addedElementCount = Self.addCount(in: container, forKey: .elements)
		addedMockCount = Self.addCount(in: container, forKey: .mocks)
		written = try? container.decodeIfPresent(BundleWritten.self, forKey: .written)
		caseMocks = (try? container.decodeIfPresent([BundleCaseMocks].self, forKey: .caseMocks)) ?? []
	}

	private static func addCount(in container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Int {
		let entries = (try? container.decodeIfPresent([BundlePlanEntry].self, forKey: key)) ?? []
		return entries.filter { $0.action == "add" }.count
	}
}

struct BundlePlanEntry: Decodable, Equatable {
	let action: String

	private enum CodingKeys: String, CodingKey {
		case action
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		action = (try? container.decodeIfPresent(String.self, forKey: .action)) ?? ""
	}
}

struct BundleWritten: Decodable, Equatable {
	let macroPaths: [String]
	let elementCount: Int
	let mockFiles: [String]

	private enum CodingKeys: String, CodingKey {
		case macroPaths = "macros"
		case elementCount = "elements"
		case mockFiles = "mocks"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		macroPaths = (try? container.decodeIfPresent([String].self, forKey: .macroPaths)) ?? []
		elementCount = (try? container.decodeIfPresent(Int.self, forKey: .elementCount)) ?? 0
		mockFiles = (try? container.decodeIfPresent([String].self, forKey: .mockFiles)) ?? []
	}
}

/// D-163: the mock variants one case ran with — served (recorded or read back from the trace) or armed by its macro.
struct BundleCaseMocks: Decodable, Equatable {
	let caseId: String
	let hasMacro: Bool
	let mocks: [BundleCaseMock]

	private enum CodingKeys: String, CodingKey {
		case caseId
		case hasMacro
		case mocks
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		caseId = (try? container.decodeIfPresent(String.self, forKey: .caseId)) ?? ""
		hasMacro = (try? container.decodeIfPresent(Bool.self, forKey: .hasMacro)) ?? false
		mocks = (try? container.decodeIfPresent([BundleCaseMock].self, forKey: .mocks)) ?? []
	}
}

struct BundleCaseMock: Decodable, Equatable {
	let endpoint: String
	let variant: String?
	let candidates: [String]

	private enum CodingKeys: String, CodingKey {
		case endpoint
		case variant
		case candidates
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		endpoint = (try? container.decodeIfPresent(String.self, forKey: .endpoint)) ?? ""
		variant = try? container.decodeIfPresent(String.self, forKey: .variant)
		candidates = (try? container.decodeIfPresent([String].self, forKey: .candidates)) ?? []
	}
}
