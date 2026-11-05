import Combine
import Foundation

/// Tests › What this case feeds the app (D-195): the recording's deeplinks and mocked JSON, to copy or download.
/// Whole-class `@MainActor`: it only maps one response to published state and forwards Copy and Save.
@MainActor
final class CaseInputsViewModel: ObservableObject {
	@Published private(set) var state: CaseInputsState = .noRecording
	@Published private(set) var mockRows: [CaseMockRowModel] = []
	@Published private(set) var message: String?

	private let service: MacroRecording
	private let desktop: DesktopActing
	private var macroId: String?
	private var task: Task<Void, Never>?

	init(service: MacroRecording, desktop: DesktopActing) {
		self.service = service
		self.desktop = desktop
	}

	deinit {
		task?.cancel()
	}

	var deeplinks: [String] {
		guard case .loaded(let inputs) = state else {
			return []
		}
		return inputs.deeplinks
	}

	var canDownloadAll: Bool {
		mockRows.contains { $0.body != nil }
	}

	func load(macroId: String?) {
		guard macroId != self.macroId else {
			return
		}
		self.macroId = macroId
		message = nil
		task?.cancel()
		guard let macroId else {
			state = .noRecording
			mockRows = []
			return
		}
		state = .loading
		let service = service
		task = Task { [weak self] in
			do {
				let inputs = try await service.inputs(macroId: macroId)
				self?.show(inputs)
			} catch {
				self?.state = .failed(message: error.localizedDescription)
			}
		}
	}

	func copy(text: String) {
		desktop.copy(text: text)
		message = String(localized: "Copied")
	}

	func download(row: CaseMockRowModel) {
		guard let body = row.body else {
			return
		}
		save(text: body, fileName: row.fileName)
	}

	/// One file with the deeplinks and every mocked body, keyed by endpoint and variant.
	func downloadAll() {
		guard case .loaded(let inputs) = state,
			let text = CaseInputsMapper.bundleText(deeplinks: inputs.deeplinks, rows: mockRows)
		else {
			return
		}
		save(text: text, fileName: "\(macroId ?? "case")-inputs.json")
	}

	private func save(text: String, fileName: String) {
		let desktop = desktop
		Task { [weak self] in
			do {
				if let url = try await desktop.saveText(text: text, suggestedFileName: fileName) {
					self?.message = String(localized: "Saved \(url.lastPathComponent)")
				}
			} catch {
				self?.message = error.localizedDescription
			}
		}
	}

	private func show(_ inputs: CaseInputs) {
		mockRows = CaseInputsMapper.rows(for: inputs.mocks)
		state = inputs.deeplinks.isEmpty && inputs.mocks.isEmpty ? .empty : .loaded(inputs)
	}
}
