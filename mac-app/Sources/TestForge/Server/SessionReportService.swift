import Foundation

/// D-176: the loaded document's test session report, as Markdown (viewer, .md) and Confluence-ready HTML.
protocol SessionReporting {
	func markdown() async throws -> String

	func confluenceHTML() async throws -> String

	/// Queues one Claude session that creates a single page under the personal Confluence page; returns its title.
	func publish() async throws -> String
}

private struct SessionPublishResponse: Decodable {
	let title: String

	private enum CodingKeys: String, CodingKey {
		case title
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? ""
	}
}

struct SessionReportService: SessionReporting {
	private let client: DashboardClient

	init(client: DashboardClient) {
		self.client = client
	}

	func markdown() async throws -> String {
		String(decoding: try await client.get(path: "api/session/report.md"), as: UTF8.self)
	}

	func confluenceHTML() async throws -> String {
		String(decoding: try await client.get(path: "api/session/report.html"), as: UTF8.self)
	}

	func publish() async throws -> String {
		let data = try await client.post(path: "api/session/publish")
		return try JSONDecoder().decode(SessionPublishResponse.self, from: data).title
	}
}
