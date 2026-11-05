import SwiftUI

/// The ? on a window's toolbar: replays the tutorials for what is on screen.
struct TutorialHelpMenuView: View {
	let features: [TutorialFeature]
	let start: (TutorialFeature) -> Void

	/// Only the main window offers the demo; it drives the main window's screens.
	var startDemo: (() -> Void)?

	/// The welcome tour (D-134), also only in the main window.
	var showWelcome: (() -> Void)?

	var body: some View {
		Menu {
			ForEach(features) { feature in
				Button {
					start(feature)
				} label: {
					Text(feature.title)
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.tutorialMenuItemPrefix + feature.rawValue)
			}
			if let showWelcome {
				Divider()
				Button("Welcome tour", action: showWelcome)
					.accessibilityIdentifier(OnboardingConstants.Accessibility.helpMenuItem)
			}
			if let startDemo {
				Divider()
				Button("Demo run (about 3 minutes)", action: startDemo)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.tutorialDemoItem)
			}
		} label: {
			Label("Tutorial", systemImage: "questionmark.circle")
		}
		.menuIndicator(.hidden)
		.help("Show a short tutorial for this screen")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.tutorialHelpButton)
	}
}
