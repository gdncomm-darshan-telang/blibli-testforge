import Foundation

protocol NetworkTrafficReading {
	func health() async throws -> LensHealthResponse
	func calls(matching searchText: String, limit: Int) async throws -> LensCallsResponse
	func callDetail(id: String) async throws -> LensCallDetail

	/// The call's real response becomes a rule with the standard answers (loaded, empty, 500, slow, timeout).
	func mockCall(id: String) async throws -> LensWriteResult

	/// Sent again from the app (mocks and breakpoints apply); the screen never sees the answer.
	func replayCall(id: String) async throws -> LensReplayResponse
}

protocol NetworkRuleEditing {
	func rules() async throws -> LensRulesResponse
	func setMocking(isEnabled: Bool) async throws -> LensWriteResult

	/// Choosing an answer also turns the rule on; the server only knows rules by endpoint here.
	func arm(endpoint: String, variantName: String) async throws -> LensWriteResult

	func disarm(endpoint: String) async throws -> LensWriteResult
	func editVariant(ruleId: String, variantId: String, fields: LensVariantFields) async throws -> LensWriteResult
	func copyVariant(ruleId: String, fromVariantId: String, name: String) async throws -> String
	func deleteVariant(ruleId: String, variantId: String) async throws -> LensWriteResult
	func timestamps(ruleId: String, variantId: String) async throws -> [LensTimestamp]
	func timeShift(ruleId: String, variantId: String, shift: LensTimeShift) async throws -> LensWriteResult
}

protocol NetworkScenarioManaging {
	func scenarios() async throws -> [LensScenario]
	func saveScenario(name: String, shouldReplace: Bool) async throws -> LensWriteResult
	func applyScenario(id: String) async throws -> LensWriteResult

	/// Restarts the app: it can't drop a scenario while running.
	func deleteScenario(id: String) async throws -> LensWriteResult
}

protocol NetworkGuarding {
	func guardrails() async throws -> LensGuardrails
	func reset(target: LensResetTarget) async throws -> LensWriteResult
}

protocol NetworkTrackerReading {
	func trackers(ask: LensTrackerAsk) async throws -> LensTrackersResponse
	func trackerFires(id: String, ask: LensTrackerAsk) async throws -> LensTrackerDetail

	/// The DA-format markdown page, same layout as the tracker-validation skill writes.
	func trackersReport(ask: LensTrackerAsk) async throws -> String
}

/// Phase D (D-130): live only, and only in an app built with the phase-D NetworkLens.
protocol NetworkBreakpointControlling {
	func breakpoints() async throws -> LensBreakpointsResponse
	func addBreakpoint(_ request: LensBreakpointRequest) async throws
	func removeBreakpoint(id: String) async throws
	func release(heldId: String, as release: LensHeldRelease) async throws -> [LensHeldCall]
	func releaseAll() async throws -> [LensHeldCall]
	func setBubble(isHidden: Bool) async throws
}

struct LensTimeShift: Equatable {
	let anchorPath: String
	let inSeconds: Int
}

enum LensResetTarget: String {
	case allOff = "off"
	case pack
}

typealias NetworkConsoleServing = NetworkTrafficReading & NetworkRuleEditing & NetworkScenarioManaging & NetworkGuarding & NetworkTrackerReading
	& NetworkBreakpointControlling

/// The Network console's one transport over the dashboard's `/api/lens/*` (D-127, D-128).
struct NetworkConsoleService: NetworkConsoleServing {
	private let client: DashboardClient
	private let decoder = JSONDecoder()

	init(client: DashboardClient) {
		self.client = client
	}

	func health() async throws -> LensHealthResponse {
		let data = try await client.get(path: "api/lens/health")
		return try decoder.decode(LensHealthResponse.self, from: data)
	}

	func calls(matching searchText: String, limit: Int) async throws -> LensCallsResponse {
		let limitText = String(limit)
		let query = [URLQueryItem(name: "grep", value: searchText), URLQueryItem(name: "limit", value: limitText)]
		let data = try await client.get(path: "api/lens/calls", queryItems: query)
		return try decoder.decode(LensCallsResponse.self, from: data)
	}

	func callDetail(id: String) async throws -> LensCallDetail {
		let data = try await client.get(path: "api/lens/calls/\(id)")
		return try decoder.decode(LensCallDetail.self, from: data)
	}

	func mockCall(id: String) async throws -> LensWriteResult {
		let data = try await client.post(path: "api/lens/calls/\(id)/mock", json: [:])
		return try decoder.decode(LensWriteResult.self, from: data)
	}

	func replayCall(id: String) async throws -> LensReplayResponse {
		let data = try await client.post(path: "api/lens/calls/\(id)/replay", json: [:])
		return try decoder.decode(LensReplayResponse.self, from: data)
	}

	func breakpoints() async throws -> LensBreakpointsResponse {
		let data = try await client.get(path: "api/lens/breakpoints")
		return try decoder.decode(LensBreakpointsResponse.self, from: data)
	}

	func addBreakpoint(_ request: LensBreakpointRequest) async throws {
		var body: [String: JSONValue] = ["stage": .string(request.stage.rawValue), "oneShot": .bool(request.isOneShot)]
		switch request.target {
			case .endpoint(let endpoint):
				body["endpoint"] = .string(endpoint)
			case .call(let id):
				body["call"] = .string(id)
		}
		_ = try await client.post(path: "api/lens/breakpoints", json: body)
	}

	func removeBreakpoint(id: String) async throws {
		_ = try await client.delete(path: "api/lens/breakpoints/\(id)")
	}

	func release(heldId: String, as release: LensHeldRelease) async throws -> [LensHeldCall] {
		var body: [String: JSONValue] = [:]
		switch release {
			case .proceed(let statusCode, let text):
				if let statusCode {
					body["status"] = .number(Double(statusCode))
				}
				if let text {
					body["body"] = .string(text)
				}
			case .fail(let failure):
				body["failure"] = .string(failure.rawValue)
		}
		let data = try await client.post(path: "api/lens/held/\(heldId)/resume", json: body)
		return try decoder.decode(LensHeldAnswer.self, from: data).held
	}

	func releaseAll() async throws -> [LensHeldCall] {
		let data = try await client.post(path: "api/lens/held/resume-all", json: [:])
		return try decoder.decode(LensHeldAnswer.self, from: data).held
	}

	func setBubble(isHidden: Bool) async throws {
		_ = try await client.post(path: "api/lens/bubble", json: ["hidden": .bool(isHidden)])
	}

	func rules() async throws -> LensRulesResponse {
		let data = try await client.get(path: "api/lens/rules")
		return try decoder.decode(LensRulesResponse.self, from: data)
	}

	func setMocking(isEnabled: Bool) async throws -> LensWriteResult {
		let data = try await client.post(path: "api/lens/mocking", json: ["enabled": .bool(isEnabled)])
		return try decoder.decode(LensWriteResult.self, from: data)
	}

	func arm(endpoint: String, variantName: String) async throws -> LensWriteResult {
		let body: [String: JSONValue] = ["endpoint": .string(endpoint), "variant": .string(variantName)]
		let data = try await client.post(path: "api/lens/rule", json: body)
		return try decoder.decode(LensWriteResult.self, from: data)
	}

	func disarm(endpoint: String) async throws -> LensWriteResult {
		let body: [String: JSONValue] = ["endpoint": .string(endpoint), "enabled": .bool(false)]
		let data = try await client.post(path: "api/lens/rule", json: body)
		return try decoder.decode(LensWriteResult.self, from: data)
	}

	func editVariant(ruleId: String, variantId: String, fields: LensVariantFields) async throws -> LensWriteResult {
		let body = Self.json(for: fields)
		let data = try await client.put(path: "api/lens/rules/\(ruleId)/variants/\(variantId)", json: body)
		return try decoder.decode(LensWriteResult.self, from: data)
	}

	func copyVariant(ruleId: String, fromVariantId: String, name: String) async throws -> String {
		let body: [String: JSONValue] = ["from": .string(fromVariantId), "name": .string(name)]
		let data = try await client.post(path: "api/lens/rules/\(ruleId)/variants", json: body)
		let answer = try decoder.decode(CopiedVariantResponse.self, from: data)
		return answer.variantId
	}

	func deleteVariant(ruleId: String, variantId: String) async throws -> LensWriteResult {
		let data = try await client.delete(path: "api/lens/rules/\(ruleId)/variants/\(variantId)")
		return try decoder.decode(LensWriteResult.self, from: data)
	}

	func timestamps(ruleId: String, variantId: String) async throws -> [LensTimestamp] {
		let data = try await client.get(path: "api/lens/rules/\(ruleId)/variants/\(variantId)/timestamps")
		return try decoder.decode(LensTimestampsResponse.self, from: data).timestamps
	}

	func timeShift(ruleId: String, variantId: String, shift: LensTimeShift) async throws -> LensWriteResult {
		let body: [String: JSONValue] = ["anchorPath": .string(shift.anchorPath), "inSeconds": .number(Double(shift.inSeconds))]
		let data = try await client.post(path: "api/lens/rules/\(ruleId)/variants/\(variantId)/timeshift", json: body)
		return try decoder.decode(LensWriteResult.self, from: data)
	}

	func scenarios() async throws -> [LensScenario] {
		let data = try await client.get(path: "api/lens/scenarios")
		return try decoder.decode(LensScenariosResponse.self, from: data).scenarios
	}

	func saveScenario(name: String, shouldReplace: Bool) async throws -> LensWriteResult {
		let body: [String: JSONValue] = ["name": .string(name), "replace": .bool(shouldReplace)]
		let data = try await client.post(path: "api/lens/scenarios", json: body)
		return try decoder.decode(LensWriteResult.self, from: data)
	}

	func applyScenario(id: String) async throws -> LensWriteResult {
		let data = try await client.post(path: "api/lens/scenarios/\(id)/apply", json: [:])
		return try decoder.decode(LensWriteResult.self, from: data)
	}

	func deleteScenario(id: String) async throws -> LensWriteResult {
		let relaunch = URLQueryItem(name: "relaunch", value: "1")
		let data = try await client.delete(path: "api/lens/scenarios/\(id)", queryItems: [relaunch])
		return try decoder.decode(LensWriteResult.self, from: data)
	}

	func guardrails() async throws -> LensGuardrails {
		let data = try await client.get(path: "api/lens/guardrails")
		return try decoder.decode(LensGuardrails.self, from: data)
	}

	func reset(target: LensResetTarget) async throws -> LensWriteResult {
		let data = try await client.post(path: "api/lens/reset", json: ["to": .string(target.rawValue)])
		return try decoder.decode(LensWriteResult.self, from: data)
	}

	func trackers(ask: LensTrackerAsk) async throws -> LensTrackersResponse {
		let data = try await client.post(path: "api/lens/trackers", json: ask.json)
		return try decoder.decode(LensTrackersResponse.self, from: data)
	}

	func trackerFires(id: String, ask: LensTrackerAsk) async throws -> LensTrackerDetail {
		let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
		let data = try await client.post(path: "api/lens/trackers/\(encodedId)", json: ask.json)
		return try decoder.decode(LensTrackerDetail.self, from: data)
	}

	func trackersReport(ask: LensTrackerAsk) async throws -> String {
		let data = try await client.post(path: "api/lens/trackers-report", json: ask.json)
		return try decoder.decode(LensTrackersReport.self, from: data).markdown
	}

	private static func json(for fields: LensVariantFields) -> [String: JSONValue] {
		let headers = fields.headers.mapValues { JSONValue.string($0) }
		var body: [String: JSONValue] = [
			"name": .string(fields.name),
			"kind": .string(fields.kind),
			"statusCode": .number(Double(fields.statusCode)),
			"delay": .number(fields.delay),
			"body": .string(fields.body),
			"headers": .object(headers)
		]
		if let failure = fields.failure {
			body["failure"] = .string(failure)
		}
		return body
	}
}

private struct CopiedVariantResponse: Decodable {
	let variantId: String

	private enum CodingKeys: String, CodingKey {
		case variant
	}

	private enum VariantKeys: String, CodingKey {
		case id
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let variant = try container.nestedContainer(keyedBy: VariantKeys.self, forKey: .variant)
		variantId = try variant.decode(String.self, forKey: .id)
	}
}
