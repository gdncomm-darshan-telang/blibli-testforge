import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
	case general
	case project
	case logins
	case phone
	case claude
	case tutorials
	case advanced

	var id: String { rawValue }

	var title: LocalizedStringResource {
		switch self {
			case .general:
				return "General"
			case .project:
				return "Project"
			case .logins:
				return "Logins"
			case .phone:
				return "Phone"
			case .claude:
				return "Claude"
			case .tutorials:
				return "Tutorials"
			case .advanced:
				return "Advanced"
		}
	}

	var symbolName: String {
		switch self {
			case .general:
				return "gearshape"
			case .project:
				return "folder"
			case .logins:
				return "person.badge.key"
			case .phone:
				return "iphone"
			case .claude:
				return "sparkles"
			case .tutorials:
				return "graduationcap"
			case .advanced:
				return "wrench.and.screwdriver"
		}
	}
}

/// Settings (#14): General, Project and Tutorials show real data so far.
struct SettingsView: View {
	@ObservedObject var viewModel: TestForgeViewModel
	@ObservedObject var appearance: AppearanceModel
	@Environment(\.openWindow) private var openWindow

	var body: some View {
		TabView {
			ForEach(SettingsTab.allCases) { tab in
				tabContent(for: tab)
					.tabItem {
						Label {
							Text(tab.title)
						} icon: {
							Image(systemName: tab.symbolName)
						}
					}
					.tag(tab)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.settingsTabPrefix + tab.rawValue)
			}
		}
		.frame(width: TestForgeConstants.Settings.width)
		.frame(minHeight: TestForgeConstants.Settings.minHeight)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.settings)
	}

	/// Measure has its own window; every other tutorial lives in the main one.
	private func replay(_ feature: TutorialFeature) {
		if feature == .measure {
			openWindow(id: TestForgeConstants.Window.measureWindowId)
			viewModel.tutorials.start(feature)
			return
		}
		openWindow(id: TestForgeConstants.Window.mainWindowId)
		viewModel.startTutorial(feature)
	}

	@ViewBuilder
	private func tabContent(for tab: SettingsTab) -> some View {
		switch tab {
			case .general:
				GeneralSettingsView(appearance: appearance, preferences: viewModel.preferences)
			case .project:
				ProjectSettingsView(dashboardDirectory: viewModel.dashboardDirectory, setup: viewModel.setupViewModel)
			case .logins:
				LoginsSettingsView(viewModel: viewModel.loginsViewModel)
			case .tutorials:
				TutorialSettingsView(
					tutorials: viewModel.tutorials,
					start: { feature in replay(feature) },
					startDemo: {
						openWindow(id: TestForgeConstants.Window.mainWindowId)
						viewModel.demoViewModel.start()
					}
				)
			case .phone, .claude, .advanced:
				SettingsTabPlaceholderView(tab: tab)
		}
	}
}
