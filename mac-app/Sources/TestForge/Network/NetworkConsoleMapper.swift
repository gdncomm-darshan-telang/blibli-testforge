import Foundation

enum NetworkHealthTone: Equatable {
	case good
	case warning
	case off
}

struct NetworkHealthModel: Equatable {
	let title: String
	let detail: String
	let symbolName: String
	let tone: NetworkHealthTone
	let isMockingEnabled: Bool
	let ruleSummary: String
}

struct TrafficCallRowModel: Identifiable, Equatable {
	let id: String
	let method: String
	let path: String
	let host: String
	let statusText: String
	let isFailure: Bool
	let durationText: String
	let isMocked: Bool
}

struct TrafficCallDetailModel: Equatable {
	let id: String
	let title: String
	let statusText: String
	let isMocked: Bool
	let responseBody: String
	let requestBody: String
	let requestHeaders: String
	let responseHeaders: String
	let curl: String
}

enum NetworkVariantKind: String, CaseIterable, Identifiable {
	case respond
	case fail
	case hang

	var id: String { rawValue }

	var title: String {
		switch self {
			case .respond:
				return String(localized: "Answer with a body")
			case .fail:
				return String(localized: "Fail the request")
			case .hang:
				return String(localized: "Never answer")
		}
	}
}

enum NetworkFailureKind: String, CaseIterable, Identifiable {
	case offline
	case timedOut
	case connectionLost

	var id: String { rawValue }

	var title: String {
		switch self {
			case .offline:
				return String(localized: "Offline")
			case .timedOut:
				return String(localized: "Timed out")
			case .connectionLost:
				return String(localized: "Connection lost")
		}
	}
}

struct NetworkVariantModel: Identifiable, Equatable {
	let id: String
	let name: String
	let kind: NetworkVariantKind?
	let statusCode: Int
	let delay: Double
	let body: String
	let headers: [String: String]
	let failure: NetworkFailureKind?
	let isEditable: Bool
	let summary: String
}

struct NetworkRuleRowModel: Identifiable, Equatable {
	let id: String
	let endpoint: String
	let method: String
	let path: String
	let isEnabled: Bool
	let activeVariantId: String
	let variants: [NetworkVariantModel]

	var activeVariant: NetworkVariantModel? {
		variants.first { $0.id == activeVariantId }
	}
}

struct NetworkScenarioModel: Identifiable, Equatable {
	let id: String
	let name: String
	let summary: String
}

struct NetworkGuardrailsModel: Equatable {
	let headline: String
	let lines: [String]
	let canResetToPack: Bool
}

/// `/api/lens/*` answers → what the console shows; every wording decision lives here, not in the views.
enum NetworkConsoleMapper {
	static func health(_ health: LensHealthResponse, rules: LensRulesResponse?) -> NetworkHealthModel {
		let isMockingEnabled = rules?.isMockingEnabled ?? false
		let armedCount = rules?.rules.filter(\.isEnabled).count ?? 0
		let ruleCount = rules?.rules.count ?? 0
		let ruleSummary = String(localized: "\(armedCount) of \(ruleCount) rules on")
		if health.isAppPolling {
			let seconds = Int(((health.lastPollMsAgo ?? 0) / 1000).rounded())
			return NetworkHealthModel(
				title: String(localized: "App connected — changes are live"),
				detail: liveDetail(health, seconds: seconds),
				symbolName: "dot.radiowaves.left.and.right",
				tone: health.isIdentified ? .good : .warning,
				isMockingEnabled: isMockingEnabled,
				ruleSummary: ruleSummary
			)
		}
		let detail = health.isAppRunning
			? String(localized: "The app is running but not checking in — NetworkLens may be off in it")
			: String(localized: "The app isn't running — changes apply on its next launch")
		return NetworkHealthModel(
			title: String(localized: "Not live"),
			detail: detail,
			symbolName: health.isAppRunning ? "exclamationmark.triangle" : "moon.zzz",
			tone: health.isAppRunning ? .warning : .off,
			isMockingEnabled: isMockingEnabled,
			ruleSummary: ruleSummary
		)
	}

	/// An unidentified app could be any simulator's, so its changes may not land where tests run (D-130).
	private static func liveDetail(_ health: LensHealthResponse, seconds: Int) -> String {
		var parts = [String(localized: "Last check-in \(seconds) s ago")]
		if !health.isIdentified {
			parts.append(String(localized: "this app build doesn't say which simulator it's on — rebuild with the phase-D NetworkLens"))
		}
		if health.otherDeviceCount > 0 {
			parts.append(String(localized: "\(health.otherDeviceCount) other simulator(s) also running the app don't get these changes"))
		}
		return parts.joined(separator: " · ")
	}

	static func callRows(_ calls: [LensCallRow]) -> [TrafficCallRowModel] {
		calls.map { call in
			let components = URLComponents(string: call.url)
			let path = components.map { $0.path + ($0.query.map { "?\($0)" } ?? "") } ?? call.url
			let status = text(of: call.status)
			let statusCode = Int(status) ?? 0
			return TrafficCallRowModel(
				id: call.id,
				method: call.method,
				path: path.isEmpty ? call.url : path,
				host: components?.host ?? "",
				statusText: status,
				isFailure: statusCode >= 400 || statusCode == 0,
				durationText: call.durationMs.map { "\(Int($0)) ms" } ?? "",
				isMocked: call.isMocked
			)
		}
	}

	static func callDetail(_ detail: LensCallDetail) -> TrafficCallDetailModel {
		TrafficCallDetailModel(
			id: detail.row.id,
			title: "\(detail.row.method) \(detail.row.url)",
			statusText: text(of: detail.row.status),
			isMocked: detail.row.isMocked,
			responseBody: detail.responseBody ?? String(localized: "(no body)"),
			requestBody: detail.requestBody ?? String(localized: "(no body)"),
			requestHeaders: headerLines(detail.requestHeaders),
			responseHeaders: headerLines(detail.responseHeaders),
			curl: detail.curl
		)
	}

	static func ruleRows(_ response: LensRulesResponse) -> [NetworkRuleRowModel] {
		response.rules.map { rule in
			let parts = rule.endpoint.split(separator: " ", maxSplits: 1).map(String.init)
			let variants = rule.variants.map(variant)
			return NetworkRuleRowModel(
				id: rule.id,
				endpoint: rule.endpoint,
				method: parts.first ?? "",
				path: parts[safe: 1] ?? rule.endpoint,
				isEnabled: rule.isEnabled,
				activeVariantId: rule.activeVariantId ?? variants.first?.id ?? "",
				variants: variants
			)
		}
	}

	static func variant(_ variant: LensVariant) -> NetworkVariantModel {
		let kind = NetworkVariantKind(rawValue: variant.kind)
		let failure = variant.failure.flatMap(NetworkFailureKind.init(rawValue:))
		let delayText = variant.delay > 0 ? String(localized: " · \(Int(variant.delay)) s delay") : ""
		let summary: String
		switch kind {
			case .respond:
				summary = String(localized: "\(variant.statusCode ?? 200)\(delayText)")
			case .fail:
				summary = (failure?.title ?? String(localized: "Fails")) + delayText
			case .hang:
				summary = String(localized: "Never answers")
			case nil:
				summary = String(localized: "\(variant.stepCount) steps — edit in NetworkLens")
		}
		return NetworkVariantModel(
			id: variant.id,
			name: variant.name,
			kind: kind,
			statusCode: variant.statusCode ?? 200,
			delay: variant.delay,
			body: variant.body ?? "",
			headers: variant.headers.mapValues(text(of:)),
			failure: failure,
			isEditable: variant.isEditable,
			summary: summary
		)
	}

	static func scenarios(_ scenarios: [LensScenario]) -> [NetworkScenarioModel] {
		scenarios.map { scenario in
			let armed = scenario.armed.isEmpty ? String(localized: "everything off") : scenario.armed.joined(separator: ", ")
			return NetworkScenarioModel(id: scenario.id, name: scenario.name, summary: armed)
		}
	}

	/// Nil when nothing is armed — the banner only appears when a leftover mock could fake a bug.
	static func guardrails(_ guardrails: LensGuardrails) -> NetworkGuardrailsModel? {
		guard !guardrails.isClean else {
			return nil
		}
		var lines = [String(localized: "On: \(guardrails.armed.joined(separator: ", "))")]
		if !guardrails.notInPack.isEmpty {
			lines.append(String(localized: "Not in the repo's mock pack (nobody else can reproduce it): \(guardrails.notInPack.joined(separator: ", "))"))
		}
		if !guardrails.differsFromPack.isEmpty {
			let changed = guardrails.differsFromPack.map { "\($0.endpoint) → \($0.variant)" }.joined(separator: ", ")
			lines.append(String(localized: "Answer differs from the repo's pack: \(changed)"))
		}
		return NetworkGuardrailsModel(
			headline: String(localized: "\(guardrails.armed.count) mocks are on — a test now sees mocked data"),
			lines: lines,
			canResetToPack: !guardrails.differsFromPack.isEmpty
		)
	}

	static func writeMessage(_ result: LensWriteResult, done: String) -> String {
		let missing = result.missing.isEmpty ? "" : String(localized: " Not found: \(result.missing.joined(separator: ", ")).")
		guard let note = result.note else {
			return done + missing
		}
		return "\(done) — \(note)\(missing)"
	}

	static func text(of value: JSONValue) -> String {
		switch value {
			case .string(let text):
				return text
			case .number(let number):
				return number.rounded() == number ? String(Int(number)) : String(number)
			case .bool(let flag):
				return flag ? "true" : "false"
			case .null:
				return "—"
			case .array, .object:
				return JSONText.pretty(value: value)
		}
	}

	private static func headerLines(_ headers: [String: JSONValue]) -> String {
		let lines = headers.keys.sorted().map { key in
			let value = headers[key].map(text(of:)) ?? ""
			return "\(key): \(value)"
		}
		return lines.joined(separator: "\n")
	}
}
