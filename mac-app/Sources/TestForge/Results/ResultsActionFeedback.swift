import Foundation

enum ResultAction: Equatable {
	case rerunFailed
	case exportReport
	case copyReport
	case exportBundle
	case accept
	case needsRerun
	case saveOverride

	var isRunAction: Bool {
		switch self {
			case .rerunFailed, .exportReport, .copyReport, .exportBundle:
				return true
			case .accept, .needsRerun, .saveOverride:
				return false
		}
	}
}

struct ResultActionOutcome: Equatable {
	let action: ResultAction
	let message: String
	let isSuccess: Bool
}

/// D-213: which Results button is working and what the last one did, so each control shows its own progress and result.
struct ResultActionFeedback: Equatable {
	let runningAction: ResultAction?
	let outcome: ResultActionOutcome?

	var isBusy: Bool {
		runningAction != nil
	}

	var runConfirmation: String? {
		confirmation { $0.isRunAction }
	}

	var reviewConfirmation: String? {
		confirmation { !$0.isRunAction }
	}

	var overrideFailure: String? {
		guard let outcome,
			outcome.action == .saveOverride,
			!outcome.isSuccess
		else {
			return nil
		}
		return outcome.message
	}

	func isRunning(_ action: ResultAction) -> Bool {
		runningAction == action
	}

	private func confirmation(where isIncluded: (ResultAction) -> Bool) -> String? {
		guard runningAction == nil,
			let outcome,
			outcome.isSuccess,
			isIncluded(outcome.action)
		else {
			return nil
		}
		return outcome.message
	}
}

/// The run header's button text, idle and while that button's work runs.
struct ResultActionLabelText {
	let title: String
	let busyTitle: String
	let systemImage: String

	init(action: ResultAction) {
		switch action {
			case .rerunFailed:
				self.init(title: String(localized: "Re-run failed…"), busyTitle: String(localized: "Starting…"), systemImage: "arrow.clockwise")
			case .exportReport:
				self.init(title: String(localized: "Export report…"), busyTitle: String(localized: "Exporting…"), systemImage: "square.and.arrow.down")
			case .copyReport:
				self.init(title: String(localized: "Copy report"), busyTitle: String(localized: "Copying…"), systemImage: "doc.on.doc")
			case .exportBundle:
				self.init(title: String(localized: "Export bundle…"), busyTitle: String(localized: "Exporting…"), systemImage: "shippingbox")
			case .accept, .needsRerun, .saveOverride:
				self.init(title: "", busyTitle: String(localized: "Saving…"), systemImage: "checkmark")
		}
	}

	private init(title: String, busyTitle: String, systemImage: String) {
		self.title = title
		self.busyTitle = busyTitle
		self.systemImage = systemImage
	}
}

struct ResultRunControls {
	let actions: ResultRunActions
	let feedback: ResultActionFeedback
}

struct ResultReviewControls {
	let actions: ResultReviewActions
	let feedback: ResultActionFeedback
}

struct OverrideVerdictSheetModel: Equatable {
	let caseId: String
	let isSaving: Bool
	let failure: String?
}
