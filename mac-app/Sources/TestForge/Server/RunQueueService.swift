import Foundation

protocol RunQueueManaging {
	func perform(action: RunQueueTaskAction, taskId: String) async throws
	func clearFinished() async throws
}

/// `/api/tasks/*`: reorder, cancel and retry what's queued on the server.
struct RunQueueService: RunQueueManaging {
	let client: DashboardClient

	func perform(action: RunQueueTaskAction, taskId: String) async throws {
		switch action {
			case .moveUp:
				try await client.post(path: "api/tasks/\(taskId)/move", body: ["direction": "up"])
			case .moveDown:
				try await client.post(path: "api/tasks/\(taskId)/move", body: ["direction": "down"])
			case .cancel:
				try await client.post(path: "api/tasks/\(taskId)/cancel")
			case .retry:
				try await client.post(path: "api/tasks/\(taskId)/retry")
		}
	}

	func clearFinished() async throws {
		try await client.post(path: "api/tasks/clear-finished")
	}
}
