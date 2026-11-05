import Foundation

struct DeeplinkParam: Decodable, Equatable, Identifiable {
	let name: String
	let isOptional: Bool

	var id: String { name }

	private enum CodingKeys: String, CodingKey {
		case name
		case isOptional
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
		isOptional = (try? container.decodeIfPresent(Bool.self, forKey: .isOptional)) ?? false
	}
}

/// One entry of the app's DeeplinkList.txt as a fill-in template, e.g. `blibli://cari/{value}`.
struct DeeplinkRoute: Decodable, Equatable, Identifiable {
	let id: String
	let description: String
	let handlerClass: String
	let template: String
	let params: [DeeplinkParam]

	/// The route regex uses syntax a template can't express; the person types the link themselves.
	let isAdvanced: Bool

	private enum CodingKeys: String, CodingKey {
		case id
		case description
		case handlerClass
		case template
		case params
		case isAdvanced
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
		description = (try? container.decodeIfPresent(String.self, forKey: .description)) ?? ""
		handlerClass = (try? container.decodeIfPresent(String.self, forKey: .handlerClass)) ?? ""
		template = (try? container.decodeIfPresent(String.self, forKey: .template)) ?? ""
		params = (try? container.decodeIfPresent([DeeplinkParam].self, forKey: .params)) ?? []
		isAdvanced = (try? container.decodeIfPresent(Bool.self, forKey: .isAdvanced)) ?? false
	}
}

struct SavedDeeplink: Decodable, Equatable, Identifiable {
	let id: String
	let name: String
	let url: String

	private enum CodingKeys: String, CodingKey {
		case id
		case name
		case url
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
		url = (try? container.decodeIfPresent(String.self, forKey: .url)) ?? ""
		name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? url
	}
}

/// One recent open, newest first on the server.
struct DeeplinkOpening: Decodable, Equatable {
	let url: String
	let isOpened: Bool
	let error: String?
	let matched: String?
	let at: String?

	private enum CodingKeys: String, CodingKey {
		case url
		case isOpened = "ok"
		case error
		case matched
		case at
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		url = (try? container.decodeIfPresent(String.self, forKey: .url)) ?? ""
		isOpened = (try? container.decodeIfPresent(Bool.self, forKey: .isOpened)) ?? false
		error = try? container.decodeIfPresent(String.self, forKey: .error)
		matched = try? container.decodeIfPresent(String.self, forKey: .matched)
		at = try? container.decodeIfPresent(String.self, forKey: .at)
	}
}

struct DeeplinkCatalog: Decodable, Equatable {
	let routes: [DeeplinkRoute]
	let saved: [SavedDeeplink]
	let history: [DeeplinkOpening]
	let appVersion: String?

	private enum CodingKeys: String, CodingKey {
		case routes
		case saved
		case history
		case appVersion
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		routes = (try? container.decodeIfPresent([DeeplinkRoute].self, forKey: .routes)) ?? []
		saved = (try? container.decodeIfPresent([SavedDeeplink].self, forKey: .saved)) ?? []
		history = (try? container.decodeIfPresent([DeeplinkOpening].self, forKey: .history)) ?? []
		appVersion = try? container.decodeIfPresent(String.self, forKey: .appVersion)
	}
}

struct DeeplinkMatchedRoute: Decodable, Equatable {
	let description: String
	let handlerClass: String

	private enum CodingKeys: String, CodingKey {
		case description
		case handlerClass
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		description = (try? container.decodeIfPresent(String.self, forKey: .description)) ?? ""
		handlerClass = (try? container.decodeIfPresent(String.self, forKey: .handlerClass)) ?? ""
	}
}

/// Which routes would catch a link; `problem` says why it can't be opened at all (e.g. a non-Blibli https link).
/// `url` is the link the server will open — a UAT-B web link comes back rewritten to `blibli://`.
struct DeeplinkMatch: Decodable, Equatable {
	let url: String?
	let problem: String?
	let matches: [DeeplinkMatchedRoute]

	private enum CodingKeys: String, CodingKey {
		case url
		case problem
		case matches
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		url = try? container.decodeIfPresent(String.self, forKey: .url)
		problem = try? container.decodeIfPresent(String.self, forKey: .problem)
		matches = (try? container.decodeIfPresent([DeeplinkMatchedRoute].self, forKey: .matches)) ?? []
	}
}

struct DeeplinkOpenResult: Decodable, Equatable {
	let matched: String?

	private enum CodingKeys: String, CodingKey {
		case matched
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		matched = try? container.decodeIfPresent(String.self, forKey: .matched)
	}
}

protocol DeeplinkProviding: Sendable {
	func catalog() async throws -> DeeplinkCatalog
	func match(url: String) async throws -> DeeplinkMatch

	/// Opens in the running app on the test simulator — no relaunch; the server refuses while a test holds the phone.
	func open(url: String) async throws -> DeeplinkOpenResult

	func save(name: String, url: String) async throws
	func removeSaved(id: String) async throws
}

/// D-157: the server's `/api/deeplinks` routes; it owns the route list, saved links and recent opens.
struct DeeplinkService: DeeplinkProviding {
	let client: DashboardClient

	func catalog() async throws -> DeeplinkCatalog {
		let data = try await client.get(path: "api/deeplinks")
		return try JSONDecoder().decode(DeeplinkCatalog.self, from: data)
	}

	func match(url: String) async throws -> DeeplinkMatch {
		let data = try await client.post(path: "api/deeplinks/match", body: ["url": url])
		return try JSONDecoder().decode(DeeplinkMatch.self, from: data)
	}

	func open(url: String) async throws -> DeeplinkOpenResult {
		let data = try await client.post(path: "api/deeplinks/open", body: ["url": url])
		return try JSONDecoder().decode(DeeplinkOpenResult.self, from: data)
	}

	func save(name: String, url: String) async throws {
		try await client.post(path: "api/deeplinks/saved", body: ["name": name, "url": url])
	}

	func removeSaved(id: String) async throws {
		try await client.delete(path: "api/deeplinks/saved/\(id)")
	}
}
