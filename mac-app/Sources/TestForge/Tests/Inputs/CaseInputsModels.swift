import Foundation

/// `GET /api/macros/v2/:id/inputs` (D-195): the deeplinks a recording opens and the mocked responses it arms.
struct CaseInputs: Decodable, Equatable {
	let deeplinks: [String]
	let mocks: [CaseMockInput]

	private enum CodingKeys: String, CodingKey {
		case deeplinks
		case mocks
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		deeplinks = (try? container.decodeIfPresent([String].self, forKey: .deeplinks)) ?? []
		mocks = (try? container.decodeIfPresent([CaseMockInput].self, forKey: .mocks)) ?? []
	}
}

struct CaseMockInput: Decodable, Equatable, Identifiable {
	let endpoint: String
	let variant: String?
	let isOff: Bool
	let isAtLaunch: Bool
	let response: CaseMockResponse?

	/// "device" when read from the simulator's NetworkLens session, "repo" from the committed mock pack.
	let source: String?

	var id: String { "\(endpoint)|\(variant ?? "")|\(isOff)" }

	private enum CodingKeys: String, CodingKey {
		case endpoint
		case variant
		case isOff
		case isAtLaunch = "atLaunch"
		case response
		case source
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		endpoint = (try? container.decodeIfPresent(String.self, forKey: .endpoint)) ?? ""
		variant = try? container.decodeIfPresent(String.self, forKey: .variant)
		isOff = (try? container.decodeIfPresent(Bool.self, forKey: .isOff)) ?? false
		isAtLaunch = (try? container.decodeIfPresent(Bool.self, forKey: .isAtLaunch)) ?? false
		response = try? container.decodeIfPresent(CaseMockResponse.self, forKey: .response)
		source = try? container.decodeIfPresent(String.self, forKey: .source)
	}
}

struct CaseMockResponse: Decodable, Equatable {
	let status: Int
	let contentType: String
	let body: String

	private enum CodingKeys: String, CodingKey {
		case status
		case contentType
		case body
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		status = (try? container.decodeIfPresent(Int.self, forKey: .status)) ?? 200
		contentType = (try? container.decodeIfPresent(String.self, forKey: .contentType)) ?? "application/json"
		body = (try? container.decodeIfPresent(String.self, forKey: .body)) ?? ""
	}
}

enum CaseInputsState: Equatable {
	case noRecording
	case loading
	case empty
	case loaded(CaseInputs)
	case failed(message: String)
}

/// One mock as the panel shows it: what it is, where its body came from, and the body ready to copy or save.
struct CaseMockRowModel: Equatable, Identifiable {
	let id: String
	let endpoint: String
	let detailText: String
	let body: String?
	let fileName: String
}
