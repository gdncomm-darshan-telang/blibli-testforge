import Foundation

/// D-213: the Tests screen's requests, so the control that started one shows its own progress.
enum TestCaseAction: Equatable {
	case replay
	case replayWithExplanations
	case recordDemo
	case runWithClaude
	case replayStale
	case overrideAndRerun
	case stop
	case saveEdit
	case saveOverride
	case revert
	case loadDocument

	/// A run start stays busy until the server lists the run, and Stop until the run ends, not just until the request returns.
	var completion: TestCaseActionCompletion {
		switch self {
			case .replay, .replayWithExplanations, .recordDemo, .runWithClaude, .replayStale, .overrideAndRerun:
				return .runListed
			case .stop:
				return .runStopped
			case .saveEdit, .saveOverride, .revert, .loadDocument:
				return .requestReturned
		}
	}

	/// Saved from a sheet, which stays open with its failure instead of an alert over it.
	var isSheetSave: Bool {
		switch self {
			case .saveEdit, .saveOverride, .overrideAndRerun:
				return true
			case .replay, .replayWithExplanations, .recordDemo, .runWithClaude, .replayStale, .stop, .revert, .loadDocument:
				return false
		}
	}
}

enum TestCaseActionCompletion: Equatable {
	case requestReturned
	case runListed
	case runStopped
}

/// What the edit and override sheets show while their Save runs, and why it failed.
struct TestCaseSheetStatus: Equatable {
	let savingAction: TestCaseAction?
	let failureMessage: String?

	var isSaving: Bool {
		savingAction != nil
	}
}

extension TestsSectionViewModel {
	func isBusy(_ action: TestCaseAction) -> Bool {
		busyAction == action
	}

	var isStopping: Bool {
		busyAction == .stop
	}

	var sheetStatus: TestCaseSheetStatus {
		let savingAction = (busyAction?.isSheetSave ?? false) ? busyAction : nil
		return TestCaseSheetStatus(savingAction: savingAction, failureMessage: sheetFailureMessage)
	}
}
