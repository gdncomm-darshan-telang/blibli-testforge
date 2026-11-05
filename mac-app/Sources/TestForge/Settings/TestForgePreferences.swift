import Combine
import Foundation

/// Settings › General switches (board C11), persisted in the app's defaults.
@MainActor
final class TestForgePreferences: ObservableObject {
	@Published var isMenuBarItemShown: Bool {
		didSet {
			defaults.set(isMenuBarItemShown, forKey: TestForgeSettingsKey.showsMenuBarItem)
		}
	}

	/// Also drives the Dock badge with the failure count, as the board pairs them.
	@Published var isFinishNotificationOn: Bool {
		didSet {
			defaults.set(isFinishNotificationOn, forKey: TestForgeSettingsKey.notifiesOnFinish)
		}
	}

	/// Off by default: while on, the server reads one extra frame per replay step, which slows the replay.
	@Published var isStepOverlayOn: Bool {
		didSet {
			defaults.set(isStepOverlayOn, forKey: TestForgeSettingsKey.outlinesSteps)
		}
	}

	/// The Claude usage bar along the bottom of the window (D-149); View › Show Claude Usage.
	@Published var isUsageBarShown: Bool {
		didSet {
			defaults.set(isUsageBarShown, forKey: TestForgeSettingsKey.showsUsageBar)
		}
	}

	/// The live overlay's and demo's language (D-165): English or Bahasa Indonesia.
	@Published var explainLanguage: DemoLanguage {
		didSet {
			defaults.set(explainLanguage.rawValue, forKey: TestForgeSettingsKey.explainLanguage)
		}
	}

	private let defaults: UserDefaults

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
		isMenuBarItemShown = defaults.object(forKey: TestForgeSettingsKey.showsMenuBarItem) as? Bool ?? true
		isFinishNotificationOn = defaults.object(forKey: TestForgeSettingsKey.notifiesOnFinish) as? Bool ?? true
		isStepOverlayOn = defaults.bool(forKey: TestForgeSettingsKey.outlinesSteps)
		isUsageBarShown = defaults.object(forKey: TestForgeSettingsKey.showsUsageBar) as? Bool ?? true
		let languageCode = defaults.string(forKey: TestForgeSettingsKey.explainLanguage) ?? ""
		explainLanguage = DemoLanguage(rawValue: languageCode) ?? .english
	}
}
