import Foundation

enum CaseInputsMapper {
	static func rows(for mocks: [CaseMockInput]) -> [CaseMockRowModel] {
		mocks.map { mock in
			CaseMockRowModel(
				id: mock.id,
				endpoint: mock.endpoint,
				detailText: detailText(for: mock),
				body: mock.response.map { prettyJSON($0.body) },
				fileName: fileName(for: mock)
			)
		}
	}

	private static func detailText(for mock: CaseMockInput) -> String {
		if mock.isOff {
			return String(localized: "Mock turned off — the real server answers")
		}
		var parts = [String(localized: "Variant “\(mock.variant ?? "—")”")]
		if let response = mock.response {
			parts.append("HTTP \(response.status)")
		}
		if mock.isAtLaunch {
			parts.append(String(localized: "armed before launch"))
		}
		switch mock.source {
			case "device":
				parts.append(String(localized: "body from the simulator"))
			case "repo":
				parts.append(String(localized: "body from the repo mock pack"))
			default:
				parts.append(String(localized: "body not on this Mac — record or import the mock first"))
		}
		return parts.joined(separator: " · ")
	}

	/// Indented JSON when the body parses, otherwise the text as served.
	static func prettyJSON(_ text: String) -> String {
		guard let data = text.data(using: .utf8),
			let object = try? JSONSerialization.jsonObject(with: data),
			let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
			let result = String(data: pretty, encoding: .utf8)
		else {
			return text
		}
		return result
	}

	static func bundleText(deeplinks: [String], rows: [CaseMockRowModel]) -> String? {
		var mocks: [String: Any] = [:]
		for row in rows {
			guard let body = row.body else {
				continue
			}
			let parsed = body.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) }
			mocks[row.id] = parsed ?? body
		}
		let bundle: [String: Any] = ["deeplinks": deeplinks, "mocks": mocks]
		guard let data = try? JSONSerialization.data(withJSONObject: bundle, options: [.prettyPrinted, .sortedKeys]) else {
			return nil
		}
		return String(data: data, encoding: .utf8)
	}

	private static func fileName(for mock: CaseMockInput) -> String {
		let raw = "\(mock.endpoint)-\(mock.variant ?? "off")"
		let safe = raw.map { $0.isLetter || $0.isNumber ? $0 : "-" }
		return String(safe).split(separator: "-").joined(separator: "-") + ".json"
	}
}
