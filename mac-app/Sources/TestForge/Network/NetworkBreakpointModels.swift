import Foundation

/// `/api/lens/breakpoints` (D-130): breakpoints set in the app and what each holds right now.
struct LensBreakpointsResponse: Decodable, Equatable {
	let breakpoints: [LensBreakpoint]
	let held: [LensHeldCall]

	private enum CodingKeys: String, CodingKey {
		case breakpoints
		case held
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		breakpoints = (try? container.decodeIfPresent([LensBreakpoint].self, forKey: .breakpoints)) ?? []
		held = (try? container.decodeIfPresent([LensHeldCall].self, forKey: .held)) ?? []
	}
}

struct LensBreakpoint: Decodable, Equatable {
	let id: String
	let endpointKey: String
	let url: String?
	let stage: String
	let isEnabled: Bool
	let isOneShot: Bool

	private enum CodingKeys: String, CodingKey {
		case id
		case endpointKey
		case url
		case stage
		case isEnabled
		case isOneShot = "oneShot"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(String.self, forKey: .id)
		endpointKey = (try? container.decodeIfPresent(String.self, forKey: .endpointKey)) ?? "?"
		url = try? container.decodeIfPresent(String.self, forKey: .url)
		stage = (try? container.decodeIfPresent(String.self, forKey: .stage)) ?? "response"
		isEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isEnabled)) ?? true
		isOneShot = (try? container.decodeIfPresent(Bool.self, forKey: .isOneShot)) ?? false
	}
}

/// Dates arrive as the app's `JSONEncoder` default: seconds since 2001-01-01.
struct LensHeldCall: Decodable, Equatable {
	let id: String
	let endpointKey: String
	let stage: String
	let pausedAt: Date?
	let autoResumeAt: Date?
	let isAutoResumeEnabled: Bool
	let method: String?
	let url: String?
	let statusCode: Int?
	let body: String?
	let bodyByteCount: Int

	private enum CodingKeys: String, CodingKey {
		case id
		case endpointKey
		case stage
		case pausedAt
		case autoResumeAt
		case isAutoResumeEnabled
		case method
		case url
		case statusCode
		case body
		case bodyByteCount
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(String.self, forKey: .id)
		endpointKey = (try? container.decodeIfPresent(String.self, forKey: .endpointKey)) ?? "?"
		stage = (try? container.decodeIfPresent(String.self, forKey: .stage)) ?? "response"
		let pausedSeconds = try? container.decodeIfPresent(Double.self, forKey: .pausedAt)
		pausedAt = pausedSeconds.map(Date.init(timeIntervalSinceReferenceDate:))
		let resumeSeconds = try? container.decodeIfPresent(Double.self, forKey: .autoResumeAt)
		autoResumeAt = resumeSeconds.map(Date.init(timeIntervalSinceReferenceDate:))
		isAutoResumeEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isAutoResumeEnabled)) ?? true
		method = try? container.decodeIfPresent(String.self, forKey: .method)
		url = try? container.decodeIfPresent(String.self, forKey: .url)
		statusCode = try? container.decodeIfPresent(Int.self, forKey: .statusCode)
		body = try? container.decodeIfPresent(String.self, forKey: .body)
		bodyByteCount = (try? container.decodeIfPresent(Int.self, forKey: .bodyByteCount)) ?? 0
	}
}

struct LensHeldAnswer: Decodable {
	let held: [LensHeldCall]

	private enum CodingKeys: String, CodingKey {
		case held
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		held = (try? container.decodeIfPresent([LensHeldCall].self, forKey: .held)) ?? []
	}
}

struct LensReplayResponse: Decodable, Equatable {
	let statusCode: Int?
	let failure: String?
	let isMockServed: Bool
	let isInFlight: Bool

	private enum CodingKeys: String, CodingKey {
		case replayed
	}

	private enum ReplayedKeys: String, CodingKey {
		case statusCode
		case failure
		case isMockServed
		case isInFlight
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let replayed = try? container.nestedContainer(keyedBy: ReplayedKeys.self, forKey: .replayed)
		statusCode = try? replayed?.decodeIfPresent(Int.self, forKey: .statusCode)
		failure = try? replayed?.decodeIfPresent(String.self, forKey: .failure)
		isMockServed = (try? replayed?.decodeIfPresent(Bool.self, forKey: .isMockServed)) ?? false
		isInFlight = (try? replayed?.decodeIfPresent(Bool.self, forKey: .isInFlight)) ?? false
	}
}

enum NetworkBreakpointStage: String, CaseIterable, Identifiable {
	case response
	case request
	case both

	var id: String { rawValue }

	var title: String {
		switch self {
			case .response:
				return String(localized: "Response")
			case .request:
				return String(localized: "Request")
			case .both:
				return String(localized: "Request & response")
		}
	}
}

/// Where a new breakpoint points: an endpoint typed by the person, or a captured call (the server takes its endpoint key).
enum LensBreakpointTarget: Equatable {
	case endpoint(String)
	case call(id: String)
}

struct LensBreakpointRequest: Equatable {
	let target: LensBreakpointTarget
	let stage: NetworkBreakpointStage
	let isOneShot: Bool
}

/// How a held call goes on: as it is or edited, or failed with a preset.
enum LensHeldRelease: Equatable {
	case proceed(statusCode: Int?, body: String?)
	case fail(NetworkFailureKind)
}
