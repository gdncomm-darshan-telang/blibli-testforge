import Foundation

enum StreamConnection: Equatable {
	case notConnected
	case connecting
	case live
	case reconnecting(attempt: Int, retryInSeconds: Int)
}

enum StateSlice: String {
	case queue
	case jobs
	case readiness
	case usage
	case device
	case harness
	case testcases
	case narration
	case scan
	case results
	case status
	case mocks
	case trace
	case testBatch
	case identity
	case claudeCli
	case remoteControl
	case prompts
}

/// Single source of truth for server state: one `/api/state/stream` connection, re-opened with backoff when it drops.
/// A fresh snapshot on every reconnect is what lets the app pick up a run that kept going while it was closed.
final class StateStore: ObservableObject {
	@MainActor @Published private(set) var slices: [String: SliceSnapshot] = [:]
	@MainActor @Published private(set) var connection: StreamConnection = .notConnected

	private let client: StateStreaming
	private weak var console: ConsoleLogging?
	private var connectionTask: Task<Void, Never>?
	private let maxBackoffSeconds = 10

	init(client: StateStreaming, console: ConsoleLogging) {
		self.client = client
		self.console = console
	}

	deinit {
		connectionTask?.cancel()
	}

	func connect(to streamURL: URL) {
		connectionTask?.cancel()
		connectionTask = Task { [weak self] in
			await self?.keepConnected(to: streamURL)
		}
	}

	@MainActor
	func value<Model: Decodable>(of slice: StateSlice, as modelType: Model.Type) -> Model? {
		slices[slice.rawValue]?.value.decoded(as: modelType)
	}

	private func keepConnected(to streamURL: URL) async {
		var attempt = 0
		while !Task.isCancelled {
			let openingConnection: StreamConnection = attempt == 0 ? .connecting : .reconnecting(attempt: attempt, retryInSeconds: 0)
			await setConnection(to: openingConnection)
			do {
				for try await event in client.events(from: streamURL) {
					attempt = 0
					await apply(event: event)
				}
				console?.append(text: "live updates closed by the server", source: .app)
			} catch {
				console?.append(text: "live updates dropped: \(error.localizedDescription)", source: .app)
			}
			guard !Task.isCancelled else {
				return
			}
			attempt += 1
			let doublingCount = min(attempt - 1, 4)
			let delaySeconds = min(1 << doublingCount, maxBackoffSeconds)
			await setConnection(to: .reconnecting(attempt: attempt, retryInSeconds: delaySeconds))
			try? await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
		}
	}

	@MainActor
	private func setConnection(to newConnection: StreamConnection) {
		if connection != newConnection {
			connection = newConnection
		}
	}

	@MainActor
	private func apply(event: StateStreamEvent) {
		switch event {
			case .snapshot(let snapshot):
				slices = snapshot.slices
				connection = .live
				console?.append(text: "live updates connected (\(snapshot.slices.count) slices)", source: .app)
			case .patch(let patch):
				slices[patch.slice] = patch.snapshot
		}
	}
}
