import Foundation

protocol PrerequisitesListing {
	/// `isRefreshing` asks Claude Code again (about 6 s) instead of the server's cached answer.
	func report(isRefreshing: Bool) async throws -> PrerequisitesReport
}

struct PrerequisitesService: PrerequisitesListing {
	let client: DashboardClient

	func report(isRefreshing: Bool) async throws -> PrerequisitesReport {
		let data = isRefreshing
			? try await client.post(path: "api/prerequisites/refresh", timeout: 90)
			: try await client.get(path: "api/prerequisites")
		return try JSONDecoder().decode(PrerequisitesReport.self, from: data)
	}
}
