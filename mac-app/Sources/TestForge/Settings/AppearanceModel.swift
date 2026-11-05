import AppKit
import Combine

enum AppearanceChoice: String, CaseIterable, Identifiable {
	case system
	case light
	case dark

	var id: String { rawValue }

	var title: LocalizedStringResource {
		switch self {
			case .system:
				return "Match the system"
			case .light:
				return "Light"
			case .dark:
				return "Dark"
		}
	}

	/// Nil follows the system appearance.
	var appearanceName: NSAppearance.Name? {
		switch self {
			case .system:
				return nil
			case .light:
				return .aqua
			case .dark:
				return .darkAqua
		}
	}
}

/// Applied through `NSApplication.appearance`, so sheets, menus and the Settings window follow it too.
@MainActor
final class AppearanceModel: ObservableObject {
	@Published var choice: AppearanceChoice {
		didSet {
			defaults.set(choice.rawValue, forKey: TestForgeSettingsKey.appearance)
			apply()
		}
	}

	private let defaults: UserDefaults
	private let application: NSApplication

	init(application: NSApplication, defaults: UserDefaults = .standard) {
		self.defaults = defaults
		self.application = application
		let storedValue = defaults.string(forKey: TestForgeSettingsKey.appearance) ?? ""
		choice = AppearanceChoice(rawValue: storedValue) ?? .system
		apply()
	}

	private func apply() {
		application.appearance = choice.appearanceName.flatMap { NSAppearance(named: $0) }
	}
}
