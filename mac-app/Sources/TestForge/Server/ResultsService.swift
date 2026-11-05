import Foundation

enum ReviewDecision: Equatable {
	case accept
	case override(verdict: String, reason: String)
	case needsRerun
}

protocol ResultsActing {
	func fetchItems(runId: String) async throws -> [ResultItem]
	func review(runId: String, caseIndex: Int, decision: ReviewDecision) async throws

	/// Starts a new batch of the run's failures; cases without a recording run through Claude.
	func rerunFailed(runId: String) async throws

	func reportMarkdown(runId: String) async throws -> String

	/// Nil compares with the server's pick: the newest earlier develop run sharing a case, else any earlier one.
	func compare(runId: String, baseRunId: String?) async throws -> RunComparison

	/// Queues a Claude task that creates one child page under the personal page only.
	func publish(runId: String) async throws
}

/// The web UI's Results endpoints (D-062), so a review made here shows in both apps.
struct ResultsService: ResultsActing {
	private let client: DashboardClient
	private let decoder: JSONDecoder

	init(client: DashboardClient, decoder: JSONDecoder = JSONDecoder()) {
		self.client = client
		self.decoder = decoder
	}

	func fetchItems(runId: String) async throws -> [ResultItem] {
		let data = try await client.get(path: "api/results/\(runId)")
		let response = try decoder.decode(ResultRunResponse.self, from: data)
		return response.items
	}

	func review(runId: String, caseIndex: Int, decision: ReviewDecision) async throws {
		let body = Self.reviewBody(for: decision)
		try await client.post(path: "api/results/\(runId)/items/\(caseIndex)/review", body: body)
	}

	func rerunFailed(runId: String) async throws {
		try await client.post(path: "api/results/\(runId)/rerun-failed")
	}

	func reportMarkdown(runId: String) async throws -> String {
		let data = try await client.get(path: "api/results/\(runId)/report.md")
		return String(decoding: data, as: UTF8.self)
	}

	func compare(runId: String, baseRunId: String?) async throws -> RunComparison {
		let queryItems = baseRunId.map { [URLQueryItem(name: "with", value: $0)] } ?? []
		let data = try await client.get(path: "api/results/\(runId)/compare", queryItems: queryItems)
		return try decoder.decode(RunComparison.self, from: data)
	}

	func publish(runId: String) async throws {
		try await client.post(path: "api/results/\(runId)/publish")
	}

	private static func reviewBody(for decision: ReviewDecision) -> [String: String] {
		switch decision {
			case .accept:
				return ["action": "accept"]
			case .override(let verdict, let reason):
				return ["action": "override", "verdict": verdict, "reason": reason]
			case .needsRerun:
				return ["action": "rerun"]
		}
	}
}
