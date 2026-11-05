import Foundation

protocol RemoteControlActing {
	func start(spawnMode: RemoteControlSpawnMode) async throws
	func stop() async throws
}

/// `/api/remote-control/*` (D-150).
struct RemoteControlService: RemoteControlActing {
	let client: DashboardClient

	func start(spawnMode: RemoteControlSpawnMode) async throws {
		try await client.post(path: "api/remote-control/start", json: ["spawnMode": .string(spawnMode.rawValue)])
	}

	func stop() async throws {
		try await client.post(path: "api/remote-control/stop")
	}
}
