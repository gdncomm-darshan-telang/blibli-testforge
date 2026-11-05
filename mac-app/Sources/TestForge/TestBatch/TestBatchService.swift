import Foundation

protocol TestBatchActing {
	func setProofRoot(path: String) async throws
	/// D-212: `isPausingActive` sets the active batch aside first instead of refusing.
	func start(name: String, isPausingActive: Bool) async throws

	/// D-212: sets the active batch aside; it collects nothing until resumed.
	func pause(batchId: String) async throws

	/// D-212: makes a paused batch active again; the server pauses a batch active at that moment first.
	func resume(batchId: String) async throws

	/// Ends the batch; the server writes `report.md` into its folder and returns where.
	func end(batchId: String) async throws -> TestBatchSummary

	/// D-184: makes an ended batch active again; the server pauses a batch active at that moment first (D-212).
	func reopen(batchId: String) async throws

	/// D-189: takes an ended batch off the list; its proof folder and report stay on disk.
	func remove(batchId: String) async throws

	/// D-201: replays every recorded case of `batchId` on the installed build, driver only, into a new Test Batch.
	func replay(batchId: String) async throws -> TestBatchReplayStart

	/// The batch's report as Markdown, written fresh (an active batch's report shows its work so far).
	func report(batchId: String) async throws -> String
}

/// `/api/settings/proof-root` and `/api/test-batches*`; the server refuses each while a test runs.
struct TestBatchService: TestBatchActing {
	/// The replay checks readiness and may pause the active batch before it answers.
	private static let replayTimeout: TimeInterval = 90

	let client: DashboardClient

	func setProofRoot(path: String) async throws {
		try await client.post(path: "api/settings/proof-root", body: ["path": path])
	}

	func start(name: String, isPausingActive: Bool) async throws {
		_ = try await client.post(path: "api/test-batches", json: ["name": .string(name), "pauseActive": .bool(isPausingActive)])
	}

	func pause(batchId: String) async throws {
		try await client.post(path: "api/test-batches/\(batchId)/pause")
	}

	func resume(batchId: String) async throws {
		try await client.post(path: "api/test-batches/\(batchId)/resume")
	}

	func end(batchId: String) async throws -> TestBatchSummary {
		let data = try await client.post(path: "api/test-batches/\(batchId)/end")
		let response = try JSONDecoder().decode(TestBatchEndResponse.self, from: data)
		return response.batch
	}

	func reopen(batchId: String) async throws {
		try await client.post(path: "api/test-batches/\(batchId)/reopen")
	}

	func remove(batchId: String) async throws {
		_ = try await client.delete(path: "api/test-batches/\(batchId)")
	}

	func replay(batchId: String) async throws -> TestBatchReplayStart {
		let data = try await client.post(path: "api/test-batches/\(batchId)/replay", json: [:], timeout: Self.replayTimeout)
		return try JSONDecoder().decode(TestBatchReplayStart.self, from: data)
	}

	func report(batchId: String) async throws -> String {
		let data = try await client.get(path: "api/test-batches/\(batchId)/report.md")
		return String(decoding: data, as: UTF8.self)
	}
}
