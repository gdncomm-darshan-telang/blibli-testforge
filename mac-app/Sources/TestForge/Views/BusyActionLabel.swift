import SwiftUI

/// D-213: an icon button's label whose icon becomes a spinner and title the busy text while its own request runs.
/// A `Label`, so an icon-only label style still shows just the spinner.
struct BusyActionLabel: View {
	let title: String
	let systemImage: String

	/// Shown with a spinner while set; nil shows the normal title and icon.
	let busyTitle: String?

	var body: some View {
		if let busyTitle {
			Label {
				Text(busyTitle)
			} icon: {
				ProgressView()
					.controlSize(.small)
			}
			.accessibilityLabel(busyTitle)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsBusyLabel)
		} else {
			Label(title, systemImage: systemImage)
		}
	}
}
