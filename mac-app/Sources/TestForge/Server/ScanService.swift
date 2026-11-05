import Foundation

protocol ScanActing {
	/// Holds the simulator until stopped; the server refuses while a test runs.
	func start() async throws

	func mark(screenName: String) async throws
	func skip() async throws
	func stop() async throws
	func showSimulator() async throws
}

struct ScanService: ScanActing {
	private let client: DashboardClient

	init(client: DashboardClient) {
		self.client = client
	}

	func start() async throws {
		try await client.post(path: "api/scan/start")
	}

	func mark(screenName: String) async throws {
		try await client.post(path: "api/scan/mark", body: ["name": screenName])
	}

	func skip() async throws {
		try await client.post(path: "api/scan/skip")
	}

	func stop() async throws {
		try await client.post(path: "api/scan/stop")
	}

	func showSimulator() async throws {
		try await client.post(path: "api/device/show")
	}
}
