import Foundation

/// D-162 run bundles: a finished run saved as one file, and that file installed and replayed on another Mac without Claude.
protocol BundleActing {
	/// The bundle JSON for a run; later runs of the same code fill in cases they finished.
	func exportBundle(runId: String) async throws -> Data

	/// What importing would do, without writing anything.
	func inspectBundle(at fileURL: URL) async throws -> BundlePreview

	/// `overwrite` replaces macros, elements and mocks that differ locally; otherwise those are kept.
	func importBundle(at fileURL: URL, overwrite: Bool) async throws -> BundlePreview

	/// Replays the bundle's recorded cases on the driver only; a failure is never sent to Claude.
	func replayBundle(id: String) async throws

	/// Switches on the mock variants one case ran with, so a person can test it by hand.
	func armCase(bundleId: String, caseId: String) async throws
}

struct BundleService: BundleActing {
	private let client: DashboardClient
	private let decoder: JSONDecoder

	init(client: DashboardClient, decoder: JSONDecoder = JSONDecoder()) {
		self.client = client
		self.decoder = decoder
	}

	func exportBundle(runId: String) async throws -> Data {
		try await client.get(path: "api/results/\(runId)/bundle")
	}

	func inspectBundle(at fileURL: URL) async throws -> BundlePreview {
		let data = try await client.post(path: "api/bundles/inspect", body: ["path": fileURL.path])
		return try decoder.decode(BundlePreview.self, from: data)
	}

	func importBundle(at fileURL: URL, overwrite: Bool) async throws -> BundlePreview {
		let body: [String: JSONValue] = ["path": .string(fileURL.path), "overwrite": .bool(overwrite)]
		let data = try await client.post(path: "api/bundles/import", json: body)
		return try decoder.decode(BundlePreview.self, from: data)
	}

	func replayBundle(id: String) async throws {
		try await client.post(path: "api/bundles/\(id)/replay")
	}

	func armCase(bundleId: String, caseId: String) async throws {
		try await client.post(path: "api/bundles/\(bundleId)/cases/\(caseId)/arm")
	}
}
