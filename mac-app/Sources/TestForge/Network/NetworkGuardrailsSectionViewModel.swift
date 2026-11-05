import Combine
import Foundation

@MainActor
protocol NetworkGuardrailsPresenting: ObservableObject {
	var state: NetworkSectionState<NetworkGuardrailsModel> { get }
	var pendingReset: LensResetTarget? { get set }
	var runningReset: LensResetTarget? { get }
	var resetFailure: String? { get }

	func requestReset(target: LensResetTarget)
	func confirmReset()
}

/// Leftover-mock warning: a mock still on after a run is the classic fake bug, so it stays visible until handled.
@MainActor
final class NetworkGuardrailsSectionViewModel: NetworkGuardrailsPresenting {
	@Published private(set) var state: NetworkSectionState<NetworkGuardrailsModel> = .notLoaded
	@Published var pendingReset: LensResetTarget?
	@Published private(set) var runningReset: LensResetTarget?
	@Published private(set) var resetFailure: String?

	private let service: NetworkGuarding
	private let events: NetworkSectionEvents
	private var resetTask: Task<Void, Never>?

	init(service: NetworkGuarding, events: NetworkSectionEvents) {
		self.service = service
		self.events = events
	}

	deinit {
		resetTask?.cancel()
	}

	func requestReset(target: LensResetTarget) {
		pendingReset = target
	}

	func confirmReset() {
		guard runningReset == nil,
			let target = pendingReset
		else {
			return
		}
		pendingReset = nil
		runningReset = target
		resetFailure = nil
		resetTask = Task { [weak self] in
			guard let self else {
				return
			}
			do {
				let result = try await service.reset(target: target)
				let done = target == .allOff ? String(localized: "Every rule off") : String(localized: "Rules reset to the repo's pack")
				let message = NetworkConsoleMapper.writeMessage(result, done: done)
				events.report(message)
			} catch {
				resetFailure = error.localizedDescription
				events.report(error.localizedDescription)
			}
			runningReset = nil
			events.didChange()
		}
	}
}

extension NetworkGuardrailsSectionViewModel: NetworkRefreshing {
	func refresh(isFullRefresh: Bool) async {
		guard isFullRefresh else {
			return
		}
		do {
			let guardrails = try await service.guardrails()
			let model = NetworkConsoleMapper.guardrails(guardrails)
			state = model.map { .loaded($0) } ?? .empty(String(localized: "No mocks on"))
		} catch {
			state = .failed(error.localizedDescription)
		}
	}
}
