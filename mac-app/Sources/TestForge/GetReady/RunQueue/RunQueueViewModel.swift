import Combine
import Foundation

/// Get Ready › Run queue (D-199): what holds the simulator, what waits, and what just finished.
/// Whole-class `@MainActor`: it maps one live slice and forwards button taps to the server.
@MainActor
final class RunQueueViewModel: ObservableObject {
	@Published var isShown = false
	@Published private(set) var content = RunQueueMapper.content(for: nil)
	@Published private(set) var message: String?
	@Published private(set) var isClearingFinished = false
	@Published private var pendingActions: [String: RunQueueTaskAction] = [:]
	@Published private var rowFailures: [String: String] = [:]

	private let store: StateStore
	private let service: RunQueueManaging
	private var cancellables = Set<AnyCancellable>()
	private var actionTasks: [String: Task<Void, Never>] = [:]
	private var clearTask: Task<Void, Never>?

	init(store: StateStore, service: RunQueueManaging) {
		self.store = store
		self.service = service
		observeStore()
	}

	deinit {
		actionTasks.values.forEach { $0.cancel() }
		clearTask?.cancel()
		cancellables.forEach { $0.cancel() }
	}

	func show() {
		message = nil
		isShown = true
	}

	func actionState(forTaskId taskId: String) -> RunQueueRowActionState {
		RunQueueRowActionState(pendingAction: pendingActions[taskId], failure: rowFailures[taskId])
	}

	/// One request per row at a time; a second tap while one is in flight is ignored rather than cancelling it.
	func perform(action: RunQueueTaskAction, taskId: String) {
		guard pendingActions[taskId] == nil else {
			return
		}
		pendingActions[taskId] = action
		rowFailures[taskId] = nil
		actionTasks[taskId] = Task { [weak self, service] in
			do {
				try await service.perform(action: action, taskId: taskId)
			} catch {
				self?.rowFailures[taskId] = error.localizedDescription
			}
			self?.pendingActions[taskId] = nil
			self?.actionTasks[taskId] = nil
		}
	}

	func clearFinished() {
		guard !isClearingFinished else {
			return
		}
		isClearingFinished = true
		message = nil
		clearTask = Task { [weak self, service] in
			do {
				try await service.clearFinished()
			} catch {
				self?.message = error.localizedDescription
			}
			self?.isClearingFinished = false
		}
	}

	private func observeStore() {
		store.$slices
			.receive(on: DispatchQueue.main)
			.sink { [weak self] _ in
				self?.refresh()
			}
			.store(in: &cancellables)
	}

	private func refresh() {
		let snapshot = store.value(of: .queue, as: RunQueueSnapshot.self)
		let newContent = RunQueueMapper.content(for: snapshot)
		if newContent != content {
			content = newContent
		}
	}
}
