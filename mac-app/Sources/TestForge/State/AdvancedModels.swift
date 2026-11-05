import Foundation

/// The `status` slice: whether the app runs, answers live control, and serves fake data.
struct LensStatus: Decodable, Equatable {
	let isAppRunning: Bool
	let isControlQueueUp: Bool
	let isMockingEnabled: Bool
	let ruleCount: Int

	private enum CodingKeys: String, CodingKey {
		case isAppRunning = "appRunning"
		case isControlQueueUp = "controlQueueUp"
		case isMockingEnabled
		case ruleCount
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		isAppRunning = (try? container.decodeIfPresent(Bool.self, forKey: .isAppRunning)) ?? false
		isControlQueueUp = (try? container.decodeIfPresent(Bool.self, forKey: .isControlQueueUp)) ?? false
		isMockingEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isMockingEnabled)) ?? false
		ruleCount = (try? container.decodeIfPresent(Int.self, forKey: .ruleCount)) ?? 0
	}
}

struct MockState: Decodable, Equatable {
	let rules: [MockRule]

	private enum CodingKeys: String, CodingKey {
		case rules = "mocks"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		rules = (try? container.decodeIfPresent([MockRule].self, forKey: .rules)) ?? []
	}
}

struct MockRule: Decodable, Equatable, Identifiable {
	let id: String
	let endpointKey: String
	let isEnabled: Bool
	let activeVariantId: String?
	let variants: [MockVariant]

	private enum CodingKeys: String, CodingKey {
		case id
		case endpointKey
		case isEnabled
		case activeVariantId = "activeVariantID"
		case variants
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
		endpointKey = (try? container.decodeIfPresent(String.self, forKey: .endpointKey)) ?? ""
		isEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isEnabled)) ?? false
		activeVariantId = try? container.decodeIfPresent(String.self, forKey: .activeVariantId)
		variants = (try? container.decodeIfPresent([MockVariant].self, forKey: .variants)) ?? []
	}
}

/// One canned answer; its first step is either a response or a transport failure (a timeout).
struct MockVariant: Decodable, Equatable, Identifiable {
	let id: String
	let name: String
	let response: MockResponse?
	let failure: MockFailure?

	private enum CodingKeys: String, CodingKey {
		case id
		case name
		case steps
	}

	private enum StepKeys: String, CodingKey {
		case respond
		case fail
	}

	private enum PayloadKeys: String, CodingKey {
		case payload = "_0"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
		name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
		var steps = try? container.nestedUnkeyedContainer(forKey: .steps)
		let firstStep = try? steps?.nestedContainer(keyedBy: StepKeys.self)
		let respond = try? firstStep?.nestedContainer(keyedBy: PayloadKeys.self, forKey: .respond)
		let fail = try? firstStep?.nestedContainer(keyedBy: PayloadKeys.self, forKey: .fail)
		response = try? respond?.decodeIfPresent(MockResponse.self, forKey: .payload)
		failure = try? fail?.decodeIfPresent(MockFailure.self, forKey: .payload)
	}
}

struct MockResponse: Decodable, Equatable {
	let statusCode: Int
	let delaySeconds: Double
	let headerCount: Int

	/// Base64, as NetworkLens stores it; decoded only when a person opens the variant.
	let bodyBase64: String

	private enum CodingKeys: String, CodingKey {
		case statusCode
		case delaySeconds = "delay"
		case headers
		case bodyBase64 = "body"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		statusCode = (try? container.decodeIfPresent(Int.self, forKey: .statusCode)) ?? 0
		delaySeconds = (try? container.decodeIfPresent(Double.self, forKey: .delaySeconds)) ?? 0
		let headers = try? container.decodeIfPresent([String: String].self, forKey: .headers)
		headerCount = headers?.count ?? 0
		bodyBase64 = (try? container.decodeIfPresent(String.self, forKey: .bodyBase64)) ?? ""
	}
}

struct MockFailure: Decodable, Equatable {
	let errorCode: Int
	let label: String

	private enum CodingKeys: String, CodingKey {
		case errorCode
		case label
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		errorCode = (try? container.decodeIfPresent(Int.self, forKey: .errorCode)) ?? 0
		label = (try? container.decodeIfPresent(String.self, forKey: .label)) ?? ""
	}
}

/// The `trace` slice: the app's latest network calls as NetworkLens recorded them.
struct TraceState: Decodable, Equatable {
	let calls: [NetworkCall]

	private enum CodingKeys: String, CodingKey {
		case calls = "entries"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		calls = (try? container.decodeIfPresent([NetworkCall].self, forKey: .calls)) ?? []
	}
}

struct NetworkCall: Decodable, Equatable, Identifiable {
	let id: String
	let method: String
	let url: String
	let status: String
	let durationMs: Double?
	let recordedAt: Date?

	private enum CodingKeys: String, CodingKey {
		case id
		case method
		case url
		case status
		case durationMs
		case recordedAt
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
		method = (try? container.decodeIfPresent(String.self, forKey: .method)) ?? ""
		url = (try? container.decodeIfPresent(String.self, forKey: .url)) ?? ""
		status = (try? container.decodeIfPresent(String.self, forKey: .status)) ?? ""
		durationMs = try? container.decodeIfPresent(Double.self, forKey: .durationMs)
		let recordedText = try? container.decodeIfPresent(String.self, forKey: .recordedAt)
		recordedAt = recordedText.flatMap { ServerDate.parse(text: $0) }
	}
}

struct MacroList: Decodable, Equatable {
	let macros: [MacroSummary]

	private enum CodingKeys: String, CodingKey {
		case macros
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		macros = (try? container.decodeIfPresent([MacroSummary].self, forKey: .macros)) ?? []
	}
}

struct MacroSummary: Decodable, Equatable, Identifiable {
	let id: String
	let name: String

	/// `flow` (a test case), `routine` (shared setup such as log in) or `bug-verify`.
	let kind: String

	let testCases: [String]
	let path: String
	let isUsingMocks: Bool
	let anchoredCount: Int
	let targetedCount: Int

	private enum CodingKeys: String, CodingKey {
		case id
		case name
		case kind
		case testCases
		case path
		case isUsingMocks = "usesMocks"
		case anchors
	}

	private enum AnchorKeys: String, CodingKey {
		case anchored
		case targeted
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
		name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
		kind = (try? container.decodeIfPresent(String.self, forKey: .kind)) ?? "flow"
		testCases = (try? container.decodeIfPresent([String].self, forKey: .testCases)) ?? []
		path = (try? container.decodeIfPresent(String.self, forKey: .path)) ?? ""
		isUsingMocks = (try? container.decodeIfPresent(Bool.self, forKey: .isUsingMocks)) ?? false
		let anchors = try? container.nestedContainer(keyedBy: AnchorKeys.self, forKey: .anchors)
		anchoredCount = (try? anchors?.decodeIfPresent(Int.self, forKey: .anchored)) ?? 0
		targetedCount = (try? anchors?.decodeIfPresent(Int.self, forKey: .targeted)) ?? 0
	}
}

struct MacroDetail: Decodable, Equatable {
	let description: String
	let steps: [MacroMapStep]

	private enum CodingKeys: String, CodingKey {
		case macro
		case steps = "map"
	}

	private enum MacroKeys: String, CodingKey {
		case description
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let macro = try? container.nestedContainer(keyedBy: MacroKeys.self, forKey: .macro)
		description = (try? macro?.decodeIfPresent(String.self, forKey: .description)) ?? ""
		steps = (try? container.decodeIfPresent([MacroMapStep].self, forKey: .steps)) ?? []
	}
}

struct MacroMapStep: Decodable, Equatable, Identifiable {
	let id: String
	let action: String
	let text: String

	/// `identifier` when the element is found by accessibility id, `label` when only by its text.
	let quality: String?

	private enum CodingKeys: String, CodingKey {
		case id
		case action = "do"
		case text
		case quality
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
		action = (try? container.decodeIfPresent(String.self, forKey: .action)) ?? ""
		text = (try? container.decodeIfPresent(String.self, forKey: .text)) ?? ""
		quality = try? container.decodeIfPresent(String.self, forKey: .quality)
	}
}

/// Who answers driver commands: the Mac app's own harness host, the web page, or nobody.
struct DriverHostStatus: Decodable, Equatable {
	let isReachable: Bool
	let hostedBy: String?
	let queuedCount: Int

	private enum CodingKeys: String, CodingKey {
		case isReachable = "reachable"
		case hostedBy
		case queuedCount = "queued"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		isReachable = (try? container.decodeIfPresent(Bool.self, forKey: .isReachable)) ?? false
		hostedBy = try? container.decodeIfPresent(String.self, forKey: .hostedBy)
		queuedCount = (try? container.decodeIfPresent(Int.self, forKey: .queuedCount)) ?? 0
	}
}

struct MacroLintReport: Decodable, Equatable {
	let errors: [String]
	let warnings: [String]
	let macroCount: Int

	private enum CodingKeys: String, CodingKey {
		case errors
		case warnings
		case macroCount = "macros"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		errors = (try? container.decodeIfPresent([String].self, forKey: .errors)) ?? []
		warnings = (try? container.decodeIfPresent([String].self, forKey: .warnings)) ?? []
		macroCount = (try? container.decodeIfPresent(Int.self, forKey: .macroCount)) ?? 0
	}
}
