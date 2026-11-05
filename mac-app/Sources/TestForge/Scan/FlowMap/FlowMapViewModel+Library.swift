import Foundation

/// What Scan › Record macro shows: the saved macros, a recording in progress, or one waiting to be saved.
enum MacroRecorderPhase: Equatable {
	case library
	case recording
	case review
}

/// D-174: Start recording → End recording → save → land on the saved macro in the list.
extension FlowMapViewModel {
	var phase: MacroRecorderPhase {
		if isRecording {
			return .recording
		}
		return recordedSteps.isEmpty ? .library : .review
	}

	var selectedMacro: RecordedMacroSummary? {
		savedMacros.first { $0.id == selectedMacroId }
	}

	var headerSummaryText: String {
		switch phase {
			case .library:
				return savedMacros.isEmpty
					? String(localized: "No macros recorded yet")
					: String(localized: "\(savedMacros.count) saved macros")
			case .recording:
				return String(localized: "Recording · \(recordedSteps.count) steps")
			case .review:
				return String(localized: "Recording ended · \(recordedSteps.count) steps not saved yet")
		}
	}

	/// Ends the recording and goes straight to saving it; nothing recorded goes back to the list.
	func endRecording() {
		stopRecording()
		if recordedSteps.isEmpty {
			startNewMap()
		} else {
			beginSaveMacro()
		}
	}

	func requestDiscard() {
		isDiscardConfirmationPresented = true
	}

	func confirmDiscard() {
		isDiscardConfirmationPresented = false
		startNewMap()
	}

	func loadSavedMacros(selecting macroId: String? = nil) {
		let service = dependencies.macroService
		isLoadingSavedMacros = true
		Task { [weak self] in
			do {
				let macros = try await service.listRecorded()
				self?.showSavedMacros(macros, selecting: macroId)
			} catch {
				self?.libraryMessage = error.localizedDescription
			}
			self?.isLoadingSavedMacros = false
		}
	}

	func editSelectedMacroSteps() {
		guard let macro = selectedMacro else {
			return
		}
		stepEditor.begin(macroId: macro.id, name: macro.name)
	}

	func replaySelectedMacro() {
		guard !isStartingMacroReplay,
			let macro = selectedMacro
		else {
			return
		}
		isStartingMacroReplay = true
		let service = dependencies.macroService
		Task { [weak self] in
			do {
				try await service.replay(macroId: macro.id)
				self?.libraryMessage = String(localized: "Replaying “\(macro.name)” on the driver — follow it in the activity bar.")
			} catch {
				self?.libraryMessage = error.localizedDescription
			}
			self?.isStartingMacroReplay = false
		}
	}

	func revealSelectedMacro() {
		guard let path = selectedMacro?.path else {
			return
		}
		dependencies.desktop.reveal(url: URL(fileURLWithPath: path))
	}

	func dismissSavedNotice() {
		savedNotice = nil
	}

	func dismissLibraryMessage() {
		libraryMessage = nil
	}

	func didSave(outcome: RecordedMacroOutcome, macroId: String?) {
		savedNotice = outcome
		startNewMap()
		loadSavedMacros(selecting: macroId)
	}

	private func showSavedMacros(_ macros: [RecordedMacroSummary], selecting macroId: String?) {
		savedMacros = macros
		if let macroId, macros.contains(where: { $0.id == macroId }) {
			selectedMacroId = macroId
		} else if selectedMacro == nil {
			selectedMacroId = macros.first?.id
		}
	}
}
