import SwiftUI

struct GeneralSettingsView: View {
	@ObservedObject var appearance: AppearanceModel
	@ObservedObject var preferences: TestForgePreferences

	var body: some View {
		Form {
			Toggle(isOn: $preferences.isMenuBarItemShown) {
				Text("Show in menu bar")
				Text("Run progress and Stop while the window is hidden")
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.settingsMenuBarToggle)
			Toggle(isOn: $preferences.isFinishNotificationOn) {
				Text("Notify when a run finishes")
				Text("The Dock badge shows the number of failures")
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.settingsNotifyToggle)
			Toggle(isOn: $preferences.isStepOverlayOn) {
				Text("Outline steps on the Simulator")
				Text("Draws the element each replay tap or check acts on; adds about 2 seconds to each")
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.settingsOutlineToggle)
			Picker(selection: $preferences.explainLanguage) {
				ForEach(DemoLanguage.allCases) { language in
					Text(language.title)
						.tag(language)
				}
			} label: {
				Text("Explanation language")
				Text("Subtitles in explained replays and demo videos")
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.settingsExplainLanguage)
			Picker("Appearance", selection: $appearance.choice) {
				ForEach(AppearanceChoice.allCases) { choice in
					Text(choice.title)
						.tag(choice)
				}
			}
			.pickerStyle(.radioGroup)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.settingsAppearance)
		}
		.formStyle(.grouped)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.settingsGeneral)
	}
}
