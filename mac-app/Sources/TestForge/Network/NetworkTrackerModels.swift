import Foundation

/// What the Trackers tab asks `/api/lens/trackers*` (D-129): expected IDs, an optional payload contract, which launches.
struct LensTrackerAsk: Equatable {
	let ids: [String]
	let contract: [String: JSONValue]?
	let isAllSessions: Bool

	var json: [String: JSONValue] {
		var body: [String: JSONValue] = [
			"ids": .array(ids.map(JSONValue.string)),
			"allSessions": .bool(isAllSessions)
		]
		if let contract {
			body["contract"] = .object(contract)
		}
		return body
	}
}

struct LensTrackersResponse: Decodable, Equatable {
	let session: String?
	let rows: [LensTrackerRow]
	let missing: [String]
	let unexpected: [String]
	let contractIdsNotListed: [String]

	private enum CodingKeys: String, CodingKey {
		case session
		case rows
		case missing
		case unexpected
		case contractIdsNotListed
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		session = try? container.decodeIfPresent(String.self, forKey: .session)
		rows = (try? container.decodeIfPresent([LensTrackerRow].self, forKey: .rows)) ?? []
		missing = (try? container.decodeIfPresent([String].self, forKey: .missing)) ?? []
		unexpected = (try? container.decodeIfPresent([String].self, forKey: .unexpected)) ?? []
		contractIdsNotListed = (try? container.decodeIfPresent([String].self, forKey: .contractIdsNotListed)) ?? []
	}
}

struct LensTrackerRow: Decodable, Equatable {
	let id: String
	let fireCount: Int
	let rejected: Int
	let event: String?
	let endpoint: String?
	let status: Int?
	let originScreen: String?
	let lastFiredAt: String?
	let problems: [String]

	private enum CodingKeys: String, CodingKey {
		case id
		case fireCount = "count"
		case rejected
		case event
		case endpoint
		case status
		case originScreen
		case lastFiredAt
		case problems
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(String.self, forKey: .id)
		fireCount = (try? container.decodeIfPresent(Int.self, forKey: .fireCount)) ?? 0
		rejected = (try? container.decodeIfPresent(Int.self, forKey: .rejected)) ?? 0
		event = try? container.decodeIfPresent(String.self, forKey: .event)
		endpoint = try? container.decodeIfPresent(String.self, forKey: .endpoint)
		status = try? container.decodeIfPresent(Int.self, forKey: .status)
		originScreen = try? container.decodeIfPresent(String.self, forKey: .originScreen)
		lastFiredAt = try? container.decodeIfPresent(String.self, forKey: .lastFiredAt)
		problems = (try? container.decodeIfPresent([String].self, forKey: .problems)) ?? []
	}
}

struct LensTrackerDetail: Decodable, Equatable {
	let id: String
	let fires: [LensTrackerFire]

	private enum CodingKeys: String, CodingKey {
		case id
		case fires
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(String.self, forKey: .id)
		fires = (try? container.decodeIfPresent([LensTrackerFire].self, forKey: .fires)) ?? []
	}
}

struct LensTrackerFire: Decodable, Equatable {
	let exchangeId: String
	let endpoint: String?
	let status: Int?
	let startedAt: String?
	let event: String?
	let originScreen: String?
	let problems: [String]
	let payload: String

	private enum CodingKeys: String, CodingKey {
		case exchangeId
		case endpoint
		case status
		case startedAt
		case event
		case originScreen
		case problems
		case payload
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		exchangeId = try container.decode(String.self, forKey: .exchangeId)
		endpoint = try? container.decodeIfPresent(String.self, forKey: .endpoint)
		status = try? container.decodeIfPresent(Int.self, forKey: .status)
		startedAt = try? container.decodeIfPresent(String.self, forKey: .startedAt)
		event = try? container.decodeIfPresent(String.self, forKey: .event)
		originScreen = try? container.decodeIfPresent(String.self, forKey: .originScreen)
		problems = (try? container.decodeIfPresent([String].self, forKey: .problems)) ?? []
		payload = (try? container.decodeIfPresent(String.self, forKey: .payload)) ?? ""
	}
}

struct LensTrackersReport: Decodable {
	let markdown: String

	private enum CodingKeys: String, CodingKey {
		case markdown
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		markdown = try container.decode(String.self, forKey: .markdown)
	}
}
