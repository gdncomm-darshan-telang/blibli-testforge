import Foundation

enum DashboardClientError: LocalizedError {
	case rejected(message: String)

	var errorDescription: String? {
		switch self {
			case .rejected(let message):
				return message
		}
	}
}

/// The one transport for the dashboard's endpoints; a refusal surfaces the server's own `{error}` text.
struct DashboardClient {
	private let baseURL: URL
	private let session: URLSession

	init(baseURL: URL, session: URLSession) {
		self.baseURL = baseURL
		self.session = session
	}

	@discardableResult
	func post(path: String, body: [String: String] = [:]) async throws -> Data {
		let endpointURL = baseURL.appendingPathComponent(path)
		var request = URLRequest(url: endpointURL)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(body)
		return try await send(request: request)
	}

	/// For bodies with real booleans or numbers: the server reads `Boolean("false")` as true.
	@discardableResult
	func post(path: String, json: [String: JSONValue]) async throws -> Data {
		let endpointURL = baseURL.appendingPathComponent(path)
		var request = URLRequest(url: endpointURL)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(json)
		return try await send(request: request)
	}

	@discardableResult
	func post(path: String, json: [String: JSONValue], timeout: TimeInterval) async throws -> Data {
		let endpointURL = baseURL.appendingPathComponent(path)
		var request = URLRequest(url: endpointURL)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(json)
		request.timeoutInterval = timeout
		return try await send(request: request)
	}

	/// For slow server work (starting the test runner takes up to 4 min); the default request gives up after 60 s.
	@discardableResult
	func post(path: String, timeout: TimeInterval) async throws -> Data {
		let endpointURL = baseURL.appendingPathComponent(path)
		var request = URLRequest(url: endpointURL)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = Data("{}".utf8)
		request.timeoutInterval = timeout
		return try await send(request: request)
	}

	@discardableResult
	func put(path: String, json: [String: JSONValue]) async throws -> Data {
		let endpointURL = baseURL.appendingPathComponent(path)
		var request = URLRequest(url: endpointURL)
		request.httpMethod = "PUT"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(json)
		return try await send(request: request)
	}

	@discardableResult
	func patch(path: String, json: [String: JSONValue]) async throws -> Data {
		let endpointURL = baseURL.appendingPathComponent(path)
		var request = URLRequest(url: endpointURL)
		request.httpMethod = "PATCH"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(json)
		return try await send(request: request)
	}

	/// Raw bytes (a screenshot upload); the server reads the body by its `Content-Type`.
	@discardableResult
	func post(path: String, data: Data, contentType: String) async throws -> Data {
		let endpointURL = baseURL.appendingPathComponent(path)
		var request = URLRequest(url: endpointURL)
		request.httpMethod = "POST"
		request.setValue(contentType, forHTTPHeaderField: "Content-Type")
		request.httpBody = data
		return try await send(request: request)
	}

	@discardableResult
	func delete(path: String, queryItems: [URLQueryItem] = []) async throws -> Data {
		let endpointURL = baseURL.appendingPathComponent(path)
		var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
		if !queryItems.isEmpty {
			components?.queryItems = queryItems
		}
		let requestURL = components?.url ?? endpointURL
		var request = URLRequest(url: requestURL)
		request.httpMethod = "DELETE"
		return try await send(request: request)
	}

	func get(path: String, queryItems: [URLQueryItem] = []) async throws -> Data {
		let endpointURL = baseURL.appendingPathComponent(path)
		var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
		if !queryItems.isEmpty {
			components?.queryItems = queryItems
		}
		let requestURL = components?.url ?? endpointURL
		let request = URLRequest(url: requestURL)
		return try await send(request: request)
	}

	private func send(request: URLRequest) async throws -> Data {
		// URLRequest's own default is 60 s; only the runner start asks for longer.
		let (data, response) = try await session.data(for: request)
		let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
		guard (200..<300).contains(statusCode) else {
			let serverError = try? JSONDecoder().decode(ServerErrorBody.self, from: data)
			let message = serverError?.message ?? String(localized: "The server answered \(statusCode).")
			throw DashboardClientError.rejected(message: message)
		}
		return data
	}
}

private struct ServerErrorBody: Decodable {
	let message: String?

	private enum CodingKeys: String, CodingKey {
		case message = "error"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		message = try? container.decodeIfPresent(String.self, forKey: .message)
	}
}
