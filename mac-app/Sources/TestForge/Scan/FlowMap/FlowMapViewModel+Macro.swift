import Foundation

/// A row in the Steps list: what was done, where, and whether replay can find it by identifier.
struct RecordedStepRowModel: Equatable, Identifiable {
	let id: String
	let number: Int
	let symbolName: String
	let actionText: String
	let screenText: String
	let warningText: String?
	let nextScreenId: String?
}

/// D-171: the recorded steps and Save as macro.
extension FlowMapViewModel {
	private static let lastModuleKey = "recordedMacroModule"
	private static let lastSubmoduleKey = "recordedMacroSubmodule"

	var recordedSteps: [RecordedStep] {
		map?.recordedSteps ?? []
	}

	var canSaveMacro: Bool {
		!isRecording && !recordedSteps.isEmpty && !isSavingMacro
	}

	var stepRows: [RecordedStepRowModel] {
		recordedSteps.enumerated().map { index, step in
			RecordedStepRowModel(
				id: step.id,
				number: index + 1,
				symbolName: step.action.gesture == .tap ? "hand.tap" : "hand.draw",
				actionText: FlowTreeBuilder.actionText(action: step.action),
				screenText: step.nextScreenName.map { "\(step.screenName) → \($0)" } ?? step.screenName,
				warningText: Self.warningText(step: step),
				nextScreenId: step.nextScreenId
			)
		}
	}

	func beginSaveMacro() {
		guard canSaveMacro else {
			return
		}
		let document = dependencies.stateStore.value(of: .testcases, as: TestCaseDocument.self)
		let options = (document?.cases ?? []).map { testCase in
			RecordedMacroCaseOption(id: testCase.id, title: "\(testCase.id) · \(testCase.scenario ?? "")")
		}
		let defaults = UserDefaults.standard
		let firstScreen = recordedSteps.first?.screenName ?? ""
		let lastScreen = recordedSteps.last { $0.nextScreenName != nil }?.nextScreenName ?? firstScreen
		saveDraft = RecordedMacroDraft(
			name: String(localized: "Recorded: \(firstScreen) to \(lastScreen)"),
			caseId: "",
			module: defaults.string(forKey: Self.lastModuleKey) ?? "Engagement",
			submodule: defaults.string(forKey: Self.lastSubmoduleKey) ?? "General",
			isFreshStart: true,
			stepCount: recordedSteps.count,
			caseOptions: options,
			missingIdentifierWarnings: recordedSteps.enumerated().compactMap { index, step in
				Self.warningText(step: step).map { "\(index + 1). \(FlowTreeBuilder.actionText(action: step.action)) — \($0)" }
			}
		)
	}

	func saveMacro(draft: RecordedMacroDraft) {
		guard draft.canSave else {
			return
		}
		saveDraft = nil
		UserDefaults.standard.set(draft.module, forKey: Self.lastModuleKey)
		UserDefaults.standard.set(draft.submodule, forKey: Self.lastSubmoduleKey)
		let request = RecordedMacroRequest(
			name: draft.name.trimmingCharacters(in: .whitespaces),
			caseIds: draft.caseId.isEmpty ? [] : [draft.caseId],
			module: draft.module.trimmingCharacters(in: .whitespaces),
			submodule: draft.submodule.trimmingCharacters(in: .whitespaces),
			isFreshStart: draft.isFreshStart,
			steps: recordedSteps
		)
		let service = dependencies.macroService
		setSaving(true)
		Task { [weak self] in
			do {
				let response = try await service.saveRecorded(request: request)
				self?.didSave(outcome: Self.outcome(response: response, caseId: draft.caseId), macroId: response.macro?.id)
			} catch {
				self?.saveOutcome = RecordedMacroOutcome(title: String(localized: "Couldn't save the macro"), message: error.localizedDescription)
			}
			self?.setSaving(false)
		}
	}

	private static func outcome(response: RecordedMacroResponse, caseId: String) -> RecordedMacroOutcome {
		let name = response.macro?.name ?? ""
		let linked = caseId.isEmpty
			? String(localized: "It isn't linked to a test case; replay it from here or Advanced › Recorded steps.")
			: String(localized: "It is linked to case \(caseId): Tests › Replay runs it without Claude.")
		var lines = [String(localized: "Saved to \(response.path)."), linked]
		if !response.warnings.isEmpty {
			lines.append(String(localized: "Needs accessibility IDs before it is reliable:"))
			lines += response.warnings.map(\.text)
		}
		return RecordedMacroOutcome(title: String(localized: "Saved “\(name)”"), message: lines.joined(separator: "\n"))
	}

	private static func warningText(step: RecordedStep) -> String? {
		guard step.isMissingIdentifier else {
			return nil
		}
		return step.action.label.isEmpty
			? String(localized: "no accessibility ID or label — replay asks a person to tap")
			: String(localized: "no accessibility ID — replay finds it by its text")
	}
}
