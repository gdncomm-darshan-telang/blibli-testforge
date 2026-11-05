import SwiftUI
import TipKit

/// One generic tip; it shows only while the coordinator names it, so order, replay and reset stay in our hands.
struct TutorialTip: Tip {
	static let nextActionId = "next"
	static let skipActionId = "skip"
	static let doneActionId = "done"

	@Parameter static var activeTipId: String = ""

	let tipId: String
	let step: TutorialStep
	let isLast: Bool

	var id: String {
		tipId
	}

	var title: Text {
		Text(step.title)
	}

	var message: Text? {
		Text(step.message)
	}

	var actions: [Action] {
		if isLast {
			return [Action(id: Self.doneActionId, title: String(localized: "Done"))]
		}
		return [
			Action(id: Self.nextActionId, title: String(localized: "Next")),
			Action(id: Self.skipActionId, title: String(localized: "Skip tutorial"))
		]
	}

	var rules: [Rule] {
		let target = tipId
		return [#Rule(Self.$activeTipId) { $0 == target }]
	}

	var options: [TipOption] {
		[Tips.IgnoresDisplayFrequency(true)]
	}
}
