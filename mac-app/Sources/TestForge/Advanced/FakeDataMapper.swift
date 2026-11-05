import Foundation

struct MockVariantOption: Equatable, Identifiable {
	let id: String
	let name: String
}

struct MockRuleRowModel: Equatable, Identifiable {
	let id: String
	let method: String
	let path: String
	let isEnabled: Bool
	let activeVariantId: String
	let variants: [MockVariantOption]
}

struct MockVariantDetailModel: Equatable {
	let ruleTitle: String
	let variantName: String
	let summary: String
	let body: String
}

struct NetworkCallRowModel: Equatable, Identifiable {
	let id: String
	let method: String
	let host: String
	let path: String
	let status: String
	let durationText: String
	let isFailure: Bool
}

struct FakeDataStatusModel: Equatable {
	let title: String
	let detail: String

	/// Off means the app answers from the real servers whatever the rules say.
	let isMockingEnabled: Bool

	let isAppRunning: Bool
}

struct FakeDataContent: Equatable {
	let status: FakeDataStatusModel
	let rules: [MockRuleRowModel]
	let calls: [NetworkCallRowModel]
}

enum FakeDataMapper {
	static func content(status: LensStatus?, mocks: MockState?, trace: TraceState?) -> FakeDataContent {
		let rules = (mocks?.rules ?? []).map(row(rule:))
		let calls = (trace?.calls ?? []).map(row(call:))
		return FakeDataContent(status: statusModel(status: status), rules: rules, calls: calls)
	}

	static func detail(rule: MockRule, variantId: String) -> MockVariantDetailModel? {
		guard let variant = rule.variants.first(where: { $0.id == variantId }) else {
			return nil
		}
		let body = variant.response.map { JSONText.decodedBody(base64: $0.bodyBase64) } ?? ""
		return MockVariantDetailModel(ruleTitle: rule.endpointKey, variantName: variant.name, summary: summary(variant: variant), body: body)
	}

	private static func statusModel(status: LensStatus?) -> FakeDataStatusModel {
		guard let status else {
			let title = String(localized: "No NetworkLens session yet")
			let detail = String(localized: "Turn NetworkLens on in the app, then mock rules appear here.")
			return FakeDataStatusModel(title: title, detail: detail, isMockingEnabled: false, isAppRunning: false)
		}
		let title = status.isMockingEnabled ? String(localized: "Network mocks are on") : String(localized: "Network mocks are off")
		let appText = status.isAppRunning ? String(localized: "app running") : String(localized: "app not running")
		let liveText = status.isControlQueueUp ? String(localized: "changes apply live") : String(localized: "changes apply on next launch")
		let detail = String(localized: "\(status.ruleCount) rules · \(appText) · \(liveText)")
		return FakeDataStatusModel(title: title, detail: detail, isMockingEnabled: status.isMockingEnabled, isAppRunning: status.isAppRunning)
	}

	private static func row(rule: MockRule) -> MockRuleRowModel {
		let parts = rule.endpointKey.split(separator: " ", maxSplits: 1).map(String.init)
		let method = parts.count == 2 ? parts[safe: 0] ?? "" : ""
		let path = parts.count == 2 ? parts[safe: 1] ?? rule.endpointKey : rule.endpointKey
		let options = rule.variants.map { MockVariantOption(id: $0.id, name: $0.name) }
		let activeVariantId = rule.activeVariantId ?? rule.variants.first?.id ?? ""
		return MockRuleRowModel(
			id: rule.id,
			method: method,
			path: path,
			isEnabled: rule.isEnabled,
			activeVariantId: activeVariantId,
			variants: options
		)
	}

	private static func row(call: NetworkCall) -> NetworkCallRowModel {
		let components = URLComponents(string: call.url)
		let host = components?.host ?? ""
		let path = components?.path ?? call.url
		let durationText = call.durationMs.map { String(localized: "\(Int($0)) ms") } ?? "—"
		let isSuccess = call.status.hasPrefix("2") || call.status.hasPrefix("3")
		return NetworkCallRowModel(
			id: call.id,
			method: call.method,
			host: host,
			path: path.isEmpty ? "/" : path,
			status: call.status,
			durationText: durationText,
			isFailure: !isSuccess
		)
	}

	private static func summary(variant: MockVariant) -> String {
		if let response = variant.response {
			let delayText = response.delaySeconds > 0 ? String(localized: " · \(response.delaySeconds, format: .number) s delay") : ""
			return String(localized: "Answers \(response.statusCode)\(delayText) · headers: \(response.headerCount)")
		}
		if let failure = variant.failure {
			let codeText = String(failure.errorCode)
			return String(localized: "Fails the request: \(failure.label) (\(codeText))")
		}
		return String(localized: "No steps")
	}
}
