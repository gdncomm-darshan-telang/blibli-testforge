import Combine
import Foundation

protocol UsageTapInstalling {
	/// Adds the tap line to the Claude Code status-line script; returns the script's path.
	func installTap() async throws -> String
}

struct UsageTapService: UsageTapInstalling {
	let client: DashboardClient

	func installTap() async throws -> String {
		let data = try await client.post(path: "api/usage/tap")
		let answer = try JSONDecoder().decode(UsageTapAnswer.self, from: data)
		return answer.scriptPath
	}
}

private struct UsageTapAnswer: Decodable {
	let scriptPath: String
}

@MainActor
protocol UsageBarPresenting: ObservableObject {
	var state: UsageBarState { get }
	var accountSummary: ClaudeAccountSummary { get }
	var message: String? { get }
	var isConnecting: Bool { get }
	var connectError: String? { get }
	var isConnectConfirmationPresented: Bool { get set }

	func askToConnect()
	func connect()
}

/// The Claude usage bar (D-149): live from the `usage` slice; offers to connect the CLI status line when empty.
/// Whole-class `@MainActor` is deliberate: it only maps one slice into published state.
@MainActor
final class UsageBarViewModel: UsageBarPresenting {
	@Published private(set) var state: UsageBarState = .noData
	@Published private(set) var accountSummary = UsageBarMapper.accountSummary(account: nil, cli: nil)
	@Published private(set) var message: String?
	@Published private(set) var isConnecting = false
	@Published private(set) var connectError: String?
	@Published var isConnectConfirmationPresented = false

	private let store: StateStore
	private let service: UsageTapInstalling
	private var cancellables = Set<AnyCancellable>()

	init(store: StateStore, service: UsageTapInstalling) {
		self.store = store
		self.service = service
		store.$slices
			.receive(on: DispatchQueue.main)
			.sink { [weak self] _ in
				self?.refresh()
			}
			.store(in: &cancellables)
	}

	func askToConnect() {
		isConnectConfirmationPresented = true
	}

	func connect() {
		guard !isConnecting else {
			return
		}
		isConnecting = true
		connectError = nil
		let service = service
		Task { [weak self] in
			do {
				let scriptPath = try await service.installTap()
				self?.message = String(localized: "Connected — figures appear with Claude Code's next status-line update (\(scriptPath))")
			} catch {
				self?.connectError = String(localized: "Couldn't connect: \(error.localizedDescription)")
			}
			self?.isConnecting = false
		}
	}

	private func refresh() {
		let usage = store.value(of: .usage, as: UsageState.self)
		let newState = UsageBarMapper.state(from: usage)
		if newState != state {
			state = newState
		}
		if case .showing = newState {
			message = nil
		}
		let account = store.value(of: .identity, as: ClaudeAccountState.self)
		let cli = store.value(of: .claudeCli, as: ClaudeCliState.self)
		let newSummary = UsageBarMapper.accountSummary(account: account, cli: cli)
		if newSummary != accountSummary {
			accountSummary = newSummary
		}
	}
}
