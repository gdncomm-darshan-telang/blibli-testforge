import SwiftUI

struct ProjectSettingsView<Setup: SetupPresenting>: View {
	let dashboardDirectory: URL
	@ObservedObject var setup: Setup

	var body: some View {
		Form {
			LabeledContent("QA server folder") {
				Text(dashboardDirectory.path)
					.textSelection(.enabled)
					.foregroundStyle(.secondary)
			}
			LabeledContent("iOS repo") {
				Button("Change repo…", action: setup.changeRepo)
					.accessibilityIdentifier(SetupConstants.Accessibility.changeRepoButton)
			}
			if let message = setup.message {
				Text(message)
					.font(.callout)
					.foregroundStyle(.red)
			}
			Text("TestForge reopens with the checkout you choose. QA_DASHBOARD_DIR and QA_PROJECT_DIR, when set, still win.")
				.font(.callout)
				.foregroundStyle(.secondary)
		}
		.formStyle(.grouped)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.settingsProject)
	}
}
