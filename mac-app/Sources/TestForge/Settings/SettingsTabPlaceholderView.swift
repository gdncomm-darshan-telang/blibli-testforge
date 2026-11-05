import SwiftUI

struct SettingsTabPlaceholderView: View {
	let tab: SettingsTab

	var body: some View {
		ContentUnavailableView {
			Label {
				Text(tab.title)
			} icon: {
				Image(systemName: tab.symbolName)
			}
		} description: {
			Text("These settings arrive in a later release.")
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.settingsTabPrefix + tab.rawValue + "_Placeholder")
	}
}
