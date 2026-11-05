import Combine
import Foundation

enum NetworkScenarioAction: Hashable {
	case save
	case apply(name: String)
	case delete(name: String)
}

extension NetworkScenarioAction {
	var progressText: String {
		switch self {
			case .save:
				return String(localized: "Saving…")
			case .apply(let name):
				return String(localized: "Applying “\(name)”…")
			case .delete(let name):
				return String(localized: "Deleting “\(name)” and restarting the app…")
		}
	}
}

struct NetworkScenarioFailure: Equatable {
	let action: NetworkScenarioAction
	let message: String
}

@MainActor
protocol NetworkScenariosPresenting: ObservableObject {
	var state: NetworkSectionState<[NetworkScenarioModel]> { get }
	var newName: String { get set }
	var pendingReplaceName: String? { get set }
	var pendingDelete: NetworkScenarioModel? { get set }
	var runningAction: NetworkScenarioAction? { get }
	var failure: NetworkScenarioFailure? { get }

	func save()
	func confirmReplace()
	func apply(scenarioId: String)
	func requestDelete(scenario: NetworkScenarioModel)
	func confirmDelete()
}

/// Scenarios: every rule's current answer saved under a name, applied in one click; deleting restarts the app.
@MainActor
final class NetworkScenariosSectionViewModel: NetworkScenariosPresenting {
	@Published private(set) var state: NetworkSectionState<[NetworkScenarioModel]> = .notLoaded
	@Published var newName = ""
	@Published var pendingReplaceName: String?
	@Published var pendingDelete: NetworkScenarioModel?
	@Published private(set) var runningAction: NetworkScenarioAction?
	@Published private(set) var failure: NetworkScenarioFailure?

	private let service: NetworkScenarioManaging
	private let events: NetworkSectionEvents
	private var actionTask: Task<Void, Never>?

	init(service: NetworkScenarioManaging, events: NetworkSectionEvents) {
		self.service = service
		self.events = events
	}

	deinit {
		actionTask?.cancel()
	}

	func save() {
		let name = newName.trimmingCharacters(in: .whitespaces)
		guard runningAction == nil,
			!name.isEmpty
		else {
			return
		}
		if state.content?.contains(where: { $0.name == name }) == true {
			pendingReplaceName = name
			return
		}
		store(name: name, shouldReplace: false)
	}

	func confirmReplace() {
		guard let name = pendingReplaceName else {
			return
		}
		pendingReplaceName = nil
		store(name: name, shouldReplace: true)
	}

	func apply(scenarioId: String) {
		let name = state.content?.first { $0.id == scenarioId }?.name ?? scenarioId
		let action = NetworkScenarioAction.apply(name: name)
		perform(action: action, done: String(localized: "Applied “\(name)”")) { service in
			try await service.applyScenario(id: scenarioId)
		}
	}

	func requestDelete(scenario: NetworkScenarioModel) {
		pendingDelete = scenario
	}

	func confirmDelete() {
		guard let scenario = pendingDelete else {
			return
		}
		pendingDelete = nil
		let action = NetworkScenarioAction.delete(name: scenario.name)
		perform(action: action, done: String(localized: "Deleted “\(scenario.name)”")) { service in
			try await service.deleteScenario(id: scenario.id)
		}
	}

	private func store(name: String, shouldReplace: Bool) {
		perform(action: .save, done: String(localized: "Saved “\(name)”")) { [weak self] service in
			let result = try await service.saveScenario(name: name, shouldReplace: shouldReplace)
			await MainActor.run {
				self?.newName = ""
			}
			return result
		}
	}

	private func perform(
		action: NetworkScenarioAction,
		done: String,
		work: @escaping (_ service: NetworkScenarioManaging) async throws -> LensWriteResult
	) {
		guard runningAction == nil else {
			return
		}
		runningAction = action
		failure = nil
		actionTask = Task { [weak self] in
			guard let self else {
				return
			}
			do {
				let result = try await work(service)
				let message = NetworkConsoleMapper.writeMessage(result, done: done)
				events.report(message)
			} catch {
				failure = NetworkScenarioFailure(action: action, message: error.localizedDescription)
				events.report(error.localizedDescription)
			}
			runningAction = nil
			events.didChange()
		}
	}
}

extension NetworkScenariosSectionViewModel: NetworkRefreshing {
	func refresh(isFullRefresh: Bool) async {
		guard isFullRefresh else {
			return
		}
		do {
			let scenarios = try await service.scenarios()
			let rows = NetworkConsoleMapper.scenarios(scenarios)
			state = rows.isEmpty ? .empty(String(localized: "No scenarios yet")) : .loaded(rows)
		} catch {
			state = .failed(error.localizedDescription)
		}
	}
}
