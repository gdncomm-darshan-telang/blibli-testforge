import Foundation

/// D-213: the pill's and the start sheet's per-control progress and failure, read from `actionState`.
extension TestBatchPresenting {
	var isWorking: Bool {
		guard case .working = actionState else {
			return false
		}
		return true
	}

	func isRunning(_ action: TestBatchAction) -> Bool {
		actionState == .working(action)
	}

	var failureMessage: String? {
		guard case .failed(_, let message) = actionState else {
			return nil
		}
		return message
	}

	/// The pill's title while it works, e.g. "Pausing…"; nil when idle.
	var workingTitle: String? {
		guard case .working(let action) = actionState else {
			return nil
		}
		switch action {
			case .chooseFolder:
				return String(localized: "Choosing proof folder…")
			case .start:
				return String(localized: "Starting Test Batch…")
			case .end:
				return String(localized: "Ending and writing report…")
			case .reopen:
				return String(localized: "Reopening…")
			case .pause:
				return String(localized: "Pausing…")
			case .resume:
				return String(localized: "Resuming…")
		}
	}

	/// The sheet shows its own failure; the pill's alert covers everything started from the menu.
	var isFailureAlertShown: Bool {
		failureMessage != nil && !isStartSheetShown
	}
}
