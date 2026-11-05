import Combine
import Foundation

/// Scan › Edit steps (D-195): reorder, remove and adjust a saved macro's steps, then write them back to its file.
/// Whole-class `@MainActor`: it holds one list being edited and forwards Save.
@MainActor
final class MacroStepEditorViewModel: ObservableObject {
	@Published private(set) var state: MacroStepEditorState = .hidden
	@Published var steps: [MacroStep] = []
	@Published private(set) var macroName = ""

	private let service: MacroRecording
	private var original: [MacroStep] = []
	private var macroId: String?
	private var task: Task<Void, Never>?

	/// Called after a save lands, so the library can reload what changed.
	var onSaved: ((String) -> Void)?

	init(service: MacroRecording) {
		self.service = service
	}

	deinit {
		task?.cancel()
	}

	var isShown: Bool {
		state != .hidden
	}

	var hasChanges: Bool {
		steps != original
	}

	var canSave: Bool {
		state == .editing && hasChanges && !steps.isEmpty
	}

	var removedCount: Int {
		original.count - steps.count
	}

	func begin(macroId: String, name: String) {
		self.macroId = macroId
		macroName = name
		state = .loading
		let service = service
		task?.cancel()
		task = Task { [weak self] in
			do {
				let list = try await service.steps(macroId: macroId)
				self?.original = list.steps
				self?.steps = list.steps
				self?.state = .editing
			} catch {
				self?.state = .failed(message: error.localizedDescription)
			}
		}
	}

	func move(from source: IndexSet, to destination: Int) {
		steps.move(fromOffsets: source, toOffset: destination)
	}

	func remove(stepId: String) {
		steps.removeAll { $0.id == stepId }
	}

	func revert() {
		steps = original
	}

	func save() {
		guard canSave,
			let macroId
		else {
			return
		}
		state = .saving
		let service = service
		let body = MacroStepEditMapper.body(original: original, edited: steps)
		task = Task { [weak self] in
			do {
				try await service.saveSteps(macroId: macroId, body: body)
				self?.onSaved?(macroId)
				self?.state = .hidden
			} catch {
				self?.state = .failed(message: error.localizedDescription)
			}
		}
	}

	func retry() {
		guard let macroId else {
			return
		}
		begin(macroId: macroId, name: macroName)
	}

	func dismiss() {
		task?.cancel()
		state = .hidden
	}
}
