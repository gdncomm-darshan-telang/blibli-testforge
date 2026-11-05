import Combine
import Foundation

/// A run waiting for a person (D-199): shows the oldest open popup over the main window until it's answered.
/// Whole-class `@MainActor`: it mirrors one slice and forwards one answer.
@MainActor
final class RunPromptViewModel: ObservableObject {
	@Published private(set) var prompt: RunPrompt?
	@Published private(set) var message: String?
	@Published private(set) var isSending = false
	@Published var value = ""

	private let store: StateStore
	private let service: RunPromptAnswering
	private var cancellables = Set<AnyCancellable>()
	private var answerTask: Task<Void, Never>?

	init(store: StateStore, service: RunPromptAnswering) {
		self.store = store
		self.service = service
		observeStore()
	}

	deinit {
		answerTask?.cancel()
		cancellables.forEach { $0.cancel() }
	}

	var doneTitle: String {
		prompt?.kind == .input ? String(localized: "Type it into the simulator") : String(localized: "Done — continue the run")
	}

	var skipTitle: String {
		prompt?.kind == .input ? String(localized: "It wasn't asked") : String(localized: "It wasn't shown")
	}

	var canSendDone: Bool {
		!isSending && (prompt?.kind != .input || !value.isEmpty)
	}

	func send(answer: RunPromptAnswer) {
		guard let prompt else {
			return
		}
		let value = prompt.kind == .input && answer == .done ? value : nil
		isSending = true
		message = nil
		answerTask = Task { [weak self, service] in
			do {
				try await service.answer(promptId: prompt.id, answer: answer, value: value)
			} catch {
				self?.message = error.localizedDescription
			}
			self?.isSending = false
		}
	}

	func showSimulator() {
		Task { [service] in
			try? await service.showSimulator()
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
		let oldest = store.value(of: .prompts, as: RunPromptList.self)?.prompts.first
		guard oldest != prompt else {
			return
		}
		prompt = oldest
		value = ""
		message = nil
	}
}
