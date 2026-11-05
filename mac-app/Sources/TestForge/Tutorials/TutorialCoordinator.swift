import Combine
import Foundation
import TipKit

enum TutorialProgress: Equatable {
	case notSeen
	case inProgress(step: Int, of: Int)
	case seen
}

private struct ActiveTutorial: Equatable {
	let feature: TutorialFeature
	let stepIndex: Int
	let runNumber: Int
}

private enum TutorialDefaultsKey {
	static let autoShow = "tutorials.autoShow"
	static let runNumber = "tutorials.runNumber"

	static func progress(_ feature: TutorialFeature) -> String {
		"tutorials.progress.\(feature.rawValue)"
	}
}

/// Runs one tutorial at a time and remembers each feature's progress in the app's defaults.
/// Tip ids carry a run number: TipKit keeps closed tips closed, so a replay needs fresh ids.
@MainActor
final class TutorialCoordinator: ObservableObject {
	@Published private(set) var progress: [TutorialFeature: TutorialProgress] = [:]
	@Published private var active: ActiveTutorial? {
		didSet {
			TutorialTip.activeTipId = active.map { tipId(for: $0) } ?? ""
		}
	}

	/// On by default: a feature's tutorial starts the first time it is opened.
	@Published var isAutoShowOn: Bool {
		didSet {
			defaults.set(isAutoShowOn, forKey: TutorialDefaultsKey.autoShow)
		}
	}

	private let defaults: UserDefaults

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
		isAutoShowOn = defaults.object(forKey: TutorialDefaultsKey.autoShow) as? Bool ?? true
		progress = Dictionary(uniqueKeysWithValues: TutorialFeature.allCases.map { ($0, Self.storedProgress(of: $0, defaults: defaults)) })
	}

	var activeFeature: TutorialFeature? {
		active?.feature
	}

	/// Lets a long screen scroll the current tip's control into view; a tip can't show off screen.
	var activeAnchor: TutorialAnchor? {
		guard let current = active else {
			return nil
		}
		return TutorialCatalog.steps(for: current.feature)[safe: current.stepIndex]?.anchor
	}

	func start(_ feature: TutorialFeature) {
		let runNumber = defaults.integer(forKey: TutorialDefaultsKey.runNumber) + 1
		defaults.set(runNumber, forKey: TutorialDefaultsKey.runNumber)
		active = ActiveTutorial(feature: feature, stepIndex: 0, runNumber: runNumber)
		record(.inProgress(step: 1, of: TutorialCatalog.steps(for: feature).count), for: feature)
	}

	/// Starts only a tutorial never seen, and never over one already showing.
	func autoStart(_ feature: TutorialFeature) {
		guard isAutoShowOn,
			active == nil,
			progress[feature] == .notSeen
		else {
			return
		}
		start(feature)
	}

	func perform(actionId: String) {
		guard let current = active else {
			return
		}
		let steps = TutorialCatalog.steps(for: current.feature)
		let nextIndex = current.stepIndex + 1
		guard actionId == TutorialTip.nextActionId,
			nextIndex < steps.count
		else {
			finish()
			return
		}
		active = ActiveTutorial(feature: current.feature, stepIndex: nextIndex, runNumber: current.runNumber)
		record(.inProgress(step: nextIndex + 1, of: steps.count), for: current.feature)
	}

	/// Every anchor gets a tip; only the active step's matches the parameter, so the rest never show.
	func tip(at anchor: TutorialAnchor) -> TutorialTip {
		guard let current = active else {
			return idleTip(at: anchor)
		}
		let steps = TutorialCatalog.steps(for: current.feature)
		guard let step = steps[safe: current.stepIndex],
			step.anchor == anchor
		else {
			return idleTip(at: anchor)
		}
		return TutorialTip(tipId: tipId(for: current), step: step, isLast: current.stepIndex == steps.count - 1)
	}

	/// Leaving a tutorial's screen stops it where it was; Settings shows it in progress and ? replays it.
	func pause() {
		active = nil
	}

	func resetAll() {
		active = nil
		for feature in TutorialFeature.allCases {
			record(.notSeen, for: feature)
		}
	}

	private func finish() {
		guard let current = active else {
			return
		}
		active = nil
		record(.seen, for: current.feature)
	}

	private func tipId(for tutorial: ActiveTutorial) -> String {
		"\(tutorial.feature.rawValue).\(tutorial.stepIndex).\(tutorial.runNumber)"
	}

	private func idleTip(at anchor: TutorialAnchor) -> TutorialTip {
		let step = TutorialStep(anchor: anchor, title: "", message: "")
		return TutorialTip(tipId: "idle.\(anchor.rawValue)", step: step, isLast: true)
	}

	private func record(_ value: TutorialProgress, for feature: TutorialFeature) {
		progress[feature] = value
		let stored: String
		switch value {
			case .notSeen:
				stored = ""
			case .inProgress(let step, let count):
				stored = "\(step)/\(count)"
			case .seen:
				stored = "seen"
		}
		defaults.set(stored, forKey: TutorialDefaultsKey.progress(feature))
	}

	private static func storedProgress(of feature: TutorialFeature, defaults: UserDefaults) -> TutorialProgress {
		let stored = defaults.string(forKey: TutorialDefaultsKey.progress(feature)) ?? ""
		if stored == "seen" {
			return .seen
		}
		let parts = stored.split(separator: "/").compactMap { Int($0) }
		guard let step = parts[safe: 0],
			let count = parts[safe: 1]
		else {
			return .notSeen
		}
		return .inProgress(step: step, of: count)
	}
}
