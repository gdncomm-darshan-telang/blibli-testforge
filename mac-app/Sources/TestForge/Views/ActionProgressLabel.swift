import SwiftUI

/// D-213: a button label that turns into a spinner plus "…ing" text while its own work runs, so a click always shows.
struct ActionProgressLabel: View {
	let title: String
	let busyTitle: String
	let isBusy: Bool

	var body: some View {
		if isBusy {
			HStack(spacing: TestForgeConstants.Spacing.small) {
				ProgressView()
					.controlSize(.small)
				Text(busyTitle)
			}
			.accessibilityElement(children: .combine)
			.accessibilityLabel(busyTitle)
		} else {
			Text(title)
		}
	}
}
