import Foundation

protocol RunStopping {
	/// Stops a batch after its current case cleans up.
	func stopBatch() async throws

	/// Continues a paused batch from its next queued case.
	func resumeBatch() async throws

	func cancelRun(jobId: String) async throws
}

struct RunControlService: RunStopping {
	private let client: DashboardClient

	init(client: DashboardClient) {
		self.client = client
	}

	func stopBatch() async throws {
		try await client.post(path: "api/batch/cancel")
	}

	func resumeBatch() async throws {
		try await client.post(path: "api/batch/resume")
	}

	func cancelRun(jobId: String) async throws {
		try await client.post(path: "api/jobs/\(jobId)/cancel")
	}
}
