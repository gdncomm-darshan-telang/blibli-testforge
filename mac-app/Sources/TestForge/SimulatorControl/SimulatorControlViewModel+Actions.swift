import Foundation

enum SimulatorCardKind: String {
	case device
	case app
	case defaults
	case reset
}

/// What a card shows beside its buttons: the work it started, or how that work ended.
enum SimulatorCardActivity: Equatable {
	case running(title: String)
	case finished(SimulatorActionResult)
}

extension SimulatorAction {
	var card: SimulatorCardKind {
		switch self {
			case .boot, .shutdown, .showSimulator, .useForTests:
				return .device
			case .relaunchApp, .killApp:
				return .app
			case .readDefault, .writeDefault, .deleteDefault:
				return .defaults
			case .resetPrivacy, .resetKeychain, .erase:
				return .reset
		}
	}
}

/// D-213: per-card state, so the card the user clicked shows its own progress and result.
extension SimulatorControlViewModel {
	func isRunning(_ action: SimulatorAction) -> Bool {
		runningAction == action
	}

	func activity(for card: SimulatorCardKind) -> SimulatorCardActivity? {
		if let action = runningAction,
			let title = runningActionTitle {
			return action.card == card ? .running(title: title) : nil
		}
		guard let result = lastResult,
			result.action?.card == card
		else {
			return nil
		}
		return .finished(result)
	}
}
