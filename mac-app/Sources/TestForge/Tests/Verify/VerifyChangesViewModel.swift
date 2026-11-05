import Combine
import Foundation

/// Tests › Verify my changes (D-196): a diff picks the recorded cases it touches; Replay hands them to the Run-all plan.
/// Whole-class `@MainActor`: it holds one form and one plan and forwards Replay.
@MainActor
final class VerifyChangesViewModel: ObservableObject {
	@Published private(set) var state: VerifyChangesState = .hidden
	@Published var base = "develop"
	@Published var isIncludingLocalEdits = true

	private let service: TestCaseActing
	private var task: Task<Void, Never>?

	/// Opens the batch plan for the picked cases; the plan sheet starts nothing until the person presses Start.
	var planReplay: (([String]) -> Void)?

	init(service: TestCaseActing) {
		self.service = service
	}

	deinit {
		task?.cancel()
	}

	var isShown: Bool {
		state != .hidden
	}

	var pickedCaseIds: [String] {
		guard case .loaded(let plan) = state else {
			return []
		}
		return plan.cases.map(\.caseId)
	}

	func begin() {
		state = .choosing
	}

	func check() {
		let trimmedBase = base.trimmingCharacters(in: .whitespaces)
		guard !trimmedBase.isEmpty else {
			return
		}
		state = .loading
		let service = service
		let isIncludingLocal = isIncludingLocalEdits
		task?.cancel()
		task = Task { [weak self] in
			do {
				let plan = try await service.verifyPlan(base: trimmedBase, isIncludingLocal: isIncludingLocal)
				self?.state = .loaded(plan)
			} catch {
				self?.state = .failed(message: error.localizedDescription)
			}
		}
	}

	func replayPicked() {
		let caseIds = pickedCaseIds
		guard !caseIds.isEmpty else {
			return
		}
		state = .hidden
		planReplay?(caseIds)
	}

	func backToForm() {
		state = .choosing
	}

	func dismiss() {
		task?.cancel()
		state = .hidden
	}
}
