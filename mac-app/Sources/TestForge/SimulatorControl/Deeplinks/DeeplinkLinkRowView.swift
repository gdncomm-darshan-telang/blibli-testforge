import SwiftUI

struct DeeplinkLinkActions {
	let open: () -> Void
	let save: () -> Void
}

struct DeeplinkLinkAvailability {
	let canOpen: Bool
	let canSave: Bool
}

/// The link being opened — built from a route or typed — with Open in app and Save.
struct DeeplinkLinkRowView: View {
	@Binding var link: String
	let availability: DeeplinkLinkAvailability
	let actions: DeeplinkLinkActions

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			TextField("Link", text: $link, prompt: Text("…or type a link yourself: blibli://… or https://www.blibli.com/…"))
				.textFieldStyle(.roundedBorder)
				.onSubmit(actions.open)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorLinkField)
			Button(action: actions.open) {
				Label("Open in app", systemImage: "arrow.up.forward.app")
			}
			.disabled(!availability.canOpen)
			.help("Opens the link in the running app on the test simulator. No relaunch: the screen opens over the current one, and Back returns there.")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorOpenLinkButton)
			Button(action: actions.save) {
				Label("Save", systemImage: "bookmark")
			}
			.disabled(!availability.canSave)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkSaveButton)
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkLinkRow)
	}
}
