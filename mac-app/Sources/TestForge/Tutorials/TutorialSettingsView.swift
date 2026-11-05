import SwiftUI

/// Settings › Tutorials: the auto-show switch, each feature's progress with Replay, and Reset all.
struct TutorialSettingsView: View {
	@ObservedObject var tutorials: TutorialCoordinator
	let start: (TutorialFeature) -> Void
	let startDemo: () -> Void

	var body: some View {
		Form {
			Section {
				Toggle("Show tutorials automatically", isOn: $tutorials.isAutoShowOn)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.tutorialAutoShowToggle)
			} footer: {
				Text("A feature's tutorial starts the first time you open it.")
					.foregroundStyle(.secondary)
			}
			Section("Tutorials") {
				ForEach(TutorialFeature.allCases) { feature in
					TutorialProgressRowView(feature: feature, progress: tutorials.progress[feature] ?? .notSeen) {
						start(feature)
					}
				}
			}
			Section {
				Button("Start demo run", action: startDemo)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.tutorialDemoStartButton)
			} header: {
				Text("Demo run")
			} footer: {
				Text("About 3 minutes, no Claude: two recorded Flash Sale tests run, then Results and Reports explain themselves.")
					.foregroundStyle(.secondary)
			}
			Section {
				Button("Reset all tutorials") {
					tutorials.resetAll()
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.tutorialResetButton)
			} footer: {
				Text("Marks every tutorial as not seen, so each shows again on first use.")
					.foregroundStyle(.secondary)
			}
		}
		.formStyle(.grouped)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.settingsTutorials)
	}
}
