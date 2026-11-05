import Foundation

protocol MockActing {
	/// The server applies it live when the app's control queue is up, otherwise quits the app so the next launch loads it.
	func setMocking(isEnabled: Bool) async throws

	func setRule(id: String, isEnabled: Bool) async throws
	func activate(ruleId: String, variantId: String) async throws

	/// Relaunches the app on the simulator, since the setting is only read at launch.
	func enableNetworkLens() async throws

	func responseBody(callId: String) async throws -> String
}

protocol MacroActing {
	func macros() async throws -> [MacroSummary]
	func detail(macroId: String) async throws -> MacroDetail
	func lint() async throws -> MacroLintReport
	func replay(macroId: String) async throws
}

protocol DriverCommanding {
	/// The server answers 409 while a test or scan holds the device.
	func send(command: [String: JSONValue]) async throws -> String

	func host() async throws -> DriverHostStatus
}

struct AdvancedService: MockActing, MacroActing, DriverCommanding {
	private let client: DashboardClient

	init(client: DashboardClient) {
		self.client = client
	}

	func setMocking(isEnabled: Bool) async throws {
		try await client.post(path: "api/mocking", json: ["enabled": .bool(isEnabled)])
	}

	func setRule(id: String, isEnabled: Bool) async throws {
		try await client.post(path: "api/mocks/\(id)/enabled", json: ["enabled": .bool(isEnabled)])
	}

	func activate(ruleId: String, variantId: String) async throws {
		try await client.post(path: "api/mocks/\(ruleId)/activate", body: ["variantId": variantId])
	}

	func enableNetworkLens() async throws {
		try await client.post(path: "api/networklens/enable")
	}

	func responseBody(callId: String) async throws -> String {
		let data = try await client.get(path: "api/trace/\(callId)/body")
		let wrapper = try JSONDecoder().decode([String: JSONValue].self, from: data)
		let body = wrapper["body"] ?? .null
		return JSONText.pretty(value: body)
	}

	func macros() async throws -> [MacroSummary] {
		let data = try await client.get(path: "api/macros")
		return try JSONDecoder().decode(MacroList.self, from: data).macros
	}

	func detail(macroId: String) async throws -> MacroDetail {
		let data = try await client.get(path: "api/macros/v2/\(macroId)")
		return try JSONDecoder().decode(MacroDetail.self, from: data)
	}

	func lint() async throws -> MacroLintReport {
		let data = try await client.get(path: "api/macros/lint")
		return try JSONDecoder().decode(MacroLintReport.self, from: data)
	}

	func replay(macroId: String) async throws {
		try await client.post(path: "api/macros/v2/\(macroId)/replay")
	}

	func send(command: [String: JSONValue]) async throws -> String {
		let data = try await client.post(path: "api/driver/command", json: command)
		let value = try JSONDecoder().decode(JSONValue.self, from: data)
		return JSONText.pretty(value: value)
	}

	func host() async throws -> DriverHostStatus {
		let data = try await client.get(path: "api/driver/host")
		return try JSONDecoder().decode(DriverHostStatus.self, from: data)
	}
}

enum JSONText {
	/// A string body (non-JSON text the server previewed) is shown as is, not quoted.
	static func pretty(value: JSONValue) -> String {
		switch value {
			case .null:
				return String(localized: "(no body)")
			case .string(let text):
				return text
			default:
				let encoder = JSONEncoder()
				encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
				let data = try? encoder.encode(value)
				return data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
		}
	}

	/// NetworkLens stores mock bodies as base64; JSON comes back pretty-printed, anything else as text.
	static func decodedBody(base64: String) -> String {
		guard let data = Data(base64Encoded: base64) else {
			return base64
		}
		if let value = try? JSONDecoder().decode(JSONValue.self, from: data) {
			return pretty(value: value)
		}
		return String(data: data, encoding: .utf8) ?? String(localized: "(\(data.count) bytes of binary data)")
	}
}
