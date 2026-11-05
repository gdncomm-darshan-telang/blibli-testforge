import Combine
import Foundation

@MainActor
protocol NetworkHealthPresenting: ObservableObject {
	var state: NetworkSectionState<NetworkHealthModel> { get }
	var isSwitching: Bool { get }

	func setMocking(isEnabled: Bool)
}

/// Health strip: is the app checking in (live vs next launch), the master switch, how many rules are on.
@MainActor
final class NetworkHealthSectionViewModel: NetworkHealthPresenting {
	@Published private(set) var state: NetworkSectionState<NetworkHealthModel> = .notLoaded
	@Published private(set) var isSwitching = false

	private let service: NetworkRuleEditing
	private let events: NetworkSectionEvents
	private var switchTask: Task<Void, Never>?

	init(service: NetworkRuleEditing, events: NetworkSectionEvents) {
		self.service = service
		self.events = events
	}

	deinit {
		switchTask?.cancel()
	}

	func update(health: LensHealthResponse, rules: LensRulesResponse?) {
		let model = NetworkConsoleMapper.health(health, rules: rules)
		state = .loaded(model)
	}

	func showFailure(message: String) {
		state = .failed(message)
	}

	func setMocking(isEnabled: Bool) {
		isSwitching = true
		switchTask?.cancel()
		switchTask = Task { [weak self] in
			guard let self else {
				return
			}
			do {
				let result = try await service.setMocking(isEnabled: isEnabled)
				let done = isEnabled ? String(localized: "Mocks on") : String(localized: "Mocks off")
				let message = NetworkConsoleMapper.writeMessage(result, done: done)
				events.report(message)
			} catch {
				events.report(error.localizedDescription)
			}
			isSwitching = false
			events.didChange()
		}
	}
}
