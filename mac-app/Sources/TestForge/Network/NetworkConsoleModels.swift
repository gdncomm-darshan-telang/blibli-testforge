import Foundation

/// `/api/lens/*` answers as the server sends them (D-127, D-128); `NetworkConsoleMapper` turns them into display models.
struct LensHealthResponse: Decodable, Equatable {
	let queueOwner: String
	let isAppRunning: Bool
	let isAppPolling: Bool
	let lastPollMsAgo: Double?

	/// D-130: false when the polling app is a build that doesn't say which simulator it runs on.
	let isIdentified: Bool

	let otherDeviceCount: Int

	private enum CodingKeys: String, CodingKey {
		case queueOwner
		case isAppRunning
		case isAppPolling
		case lastPollMsAgo
		case isIdentified
		case otherDevices
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		queueOwner = (try? container.decodeIfPresent(String.self, forKey: .queueOwner)) ?? "none"
		isAppRunning = (try? container.decodeIfPresent(Bool.self, forKey: .isAppRunning)) ?? false
		isAppPolling = (try? container.decodeIfPresent(Bool.self, forKey: .isAppPolling)) ?? false
		lastPollMsAgo = try? container.decodeIfPresent(Double.self, forKey: .lastPollMsAgo)
		isIdentified = (try? container.decodeIfPresent(Bool.self, forKey: .isIdentified)) ?? true
		otherDeviceCount = (try? container.decodeIfPresent([JSONValue].self, forKey: .otherDevices))?.count ?? 0
	}
}

struct LensCallsResponse: Decodable {
	let calls: [LensCallRow]
	let note: String?

	private enum CodingKeys: String, CodingKey {
		case calls
		case note
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		calls = (try? container.decodeIfPresent([LensCallRow].self, forKey: .calls)) ?? []
		note = try? container.decodeIfPresent(String.self, forKey: .note)
	}
}

struct LensCallRow: Decodable, Equatable {
	let id: String
	let method: String
	let url: String
	let status: JSONValue
	let durationMs: Double?
	let isMocked: Bool
	let recordedAt: String?

	private enum CodingKeys: String, CodingKey {
		case id
		case method
		case url
		case status
		case durationMs
		case isMocked
		case recordedAt
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? ""
		method = (try? container.decodeIfPresent(String.self, forKey: .method)) ?? "?"
		url = (try? container.decodeIfPresent(String.self, forKey: .url)) ?? ""
		status = (try? container.decodeIfPresent(JSONValue.self, forKey: .status)) ?? .null
		durationMs = try? container.decodeIfPresent(Double.self, forKey: .durationMs)
		isMocked = (try? container.decodeIfPresent(Bool.self, forKey: .isMocked)) ?? false
		recordedAt = try? container.decodeIfPresent(String.self, forKey: .recordedAt)
	}
}

struct LensCallDetail: Decodable, Equatable {
	let row: LensCallRow
	let requestHeaders: [String: JSONValue]
	let responseHeaders: [String: JSONValue]
	let requestBody: String?
	let responseBody: String?
	let curl: String

	private enum CodingKeys: String, CodingKey {
		case requestHeaders
		case responseHeaders
		case requestBody
		case responseBody
		case curl
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		row = try LensCallRow(from: decoder)
		requestHeaders = (try? container.decodeIfPresent([String: JSONValue].self, forKey: .requestHeaders)) ?? [:]
		responseHeaders = (try? container.decodeIfPresent([String: JSONValue].self, forKey: .responseHeaders)) ?? [:]
		requestBody = try? container.decodeIfPresent(String.self, forKey: .requestBody)
		responseBody = try? container.decodeIfPresent(String.self, forKey: .responseBody)
		curl = (try? container.decodeIfPresent(String.self, forKey: .curl)) ?? ""
	}
}

struct LensRulesResponse: Decodable {
	let source: String
	let isMockingEnabled: Bool
	let rules: [LensRule]

	private enum CodingKeys: String, CodingKey {
		case source
		case isMockingEnabled
		case rules
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		source = (try? container.decodeIfPresent(String.self, forKey: .source)) ?? "file"
		isMockingEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isMockingEnabled)) ?? false
		rules = (try? container.decodeIfPresent([LensRule].self, forKey: .rules)) ?? []
	}
}

struct LensRule: Decodable, Equatable {
	let id: String
	let endpoint: String
	let isEnabled: Bool
	let activeVariantId: String?
	let variants: [LensVariant]

	private enum CodingKeys: String, CodingKey {
		case id
		case endpoint
		case isEnabled
		case activeVariantId
		case variants
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? ""
		endpoint = (try? container.decodeIfPresent(String.self, forKey: .endpoint)) ?? ""
		isEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isEnabled)) ?? false
		activeVariantId = try? container.decodeIfPresent(String.self, forKey: .activeVariantId)
		variants = (try? container.decodeIfPresent([LensVariant].self, forKey: .variants)) ?? []
	}
}

struct LensVariant: Decodable, Equatable {
	let id: String
	let name: String
	let kind: String
	let isEditable: Bool
	let stepCount: Int
	let statusCode: Int?
	let headers: [String: JSONValue]
	let delay: Double
	let body: String?
	let failure: String?

	private enum CodingKeys: String, CodingKey {
		case id
		case name
		case kind
		case isEditable
		case stepCount
		case statusCode
		case headers
		case delay
		case body
		case failure
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? ""
		name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
		kind = (try? container.decodeIfPresent(String.self, forKey: .kind)) ?? "unknown"
		isEditable = (try? container.decodeIfPresent(Bool.self, forKey: .isEditable)) ?? false
		stepCount = (try? container.decodeIfPresent(Int.self, forKey: .stepCount)) ?? 0
		statusCode = try? container.decodeIfPresent(Int.self, forKey: .statusCode)
		headers = (try? container.decodeIfPresent([String: JSONValue].self, forKey: .headers)) ?? [:]
		delay = (try? container.decodeIfPresent(Double.self, forKey: .delay)) ?? 0
		body = try? container.decodeIfPresent(String.self, forKey: .body)
		failure = try? container.decodeIfPresent(String.self, forKey: .failure)
	}
}

struct LensScenariosResponse: Decodable {
	let scenarios: [LensScenario]

	private enum CodingKeys: String, CodingKey {
		case scenarios
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		scenarios = (try? container.decodeIfPresent([LensScenario].self, forKey: .scenarios)) ?? []
	}
}

struct LensScenario: Decodable, Equatable {
	let id: String
	let name: String
	let armed: [String]
	let ruleCount: Int

	private enum CodingKeys: String, CodingKey {
		case id
		case name
		case armed
		case ruleCount
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? ""
		name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
		armed = (try? container.decodeIfPresent([String].self, forKey: .armed)) ?? []
		ruleCount = (try? container.decodeIfPresent(Int.self, forKey: .ruleCount)) ?? 0
	}
}

struct LensGuardrails: Decodable, Equatable {
	let armed: [String]
	let notInPack: [String]
	let differsFromPack: [LensPackDifference]
	let isClean: Bool

	private enum CodingKeys: String, CodingKey {
		case armed
		case notInPack
		case differsFromPack
		case isClean
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		armed = (try? container.decodeIfPresent([String].self, forKey: .armed)) ?? []
		notInPack = (try? container.decodeIfPresent([String].self, forKey: .notInPack)) ?? []
		differsFromPack = (try? container.decodeIfPresent([LensPackDifference].self, forKey: .differsFromPack)) ?? []
		isClean = (try? container.decodeIfPresent(Bool.self, forKey: .isClean)) ?? true
	}
}

struct LensPackDifference: Decodable, Equatable {
	let endpoint: String
	let variant: String

	private enum CodingKeys: String, CodingKey {
		case endpoint
		case variant
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		endpoint = (try? container.decodeIfPresent(String.self, forKey: .endpoint)) ?? ""
		variant = (try? container.decodeIfPresent(String.self, forKey: .variant)) ?? ""
	}
}

struct LensTimestampsResponse: Decodable {
	let timestamps: [LensTimestamp]

	private enum CodingKeys: String, CodingKey {
		case timestamps
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		timestamps = (try? container.decodeIfPresent([LensTimestamp].self, forKey: .timestamps)) ?? []
	}
}

struct LensTimestamp: Decodable, Equatable {
	let path: String
	let inSeconds: Int

	private enum CodingKeys: String, CodingKey {
		case path
		case inSeconds
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		path = (try? container.decodeIfPresent(String.self, forKey: .path)) ?? ""
		inSeconds = (try? container.decodeIfPresent(Int.self, forKey: .inSeconds)) ?? 0
	}
}

/// Every write answers with where it landed: live in the app, or saved for the next launch.
struct LensWriteResult: Decodable {
	let note: String?
	let missing: [String]

	private enum CodingKeys: String, CodingKey {
		case note
		case missing
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		note = try? container.decodeIfPresent(String.self, forKey: .note)
		missing = (try? container.decodeIfPresent([String].self, forKey: .missing)) ?? []
	}
}

/// The fields a variant edit sends; `kind` is respond, fail or hang.
struct LensVariantFields: Equatable {
	let name: String
	let kind: String
	let statusCode: Int
	let delay: Double
	let body: String
	let failure: String?
	let headers: [String: String]
}
