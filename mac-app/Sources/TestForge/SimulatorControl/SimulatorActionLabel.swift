import SwiftUI

/// A card button's label whose icon turns into a spinner while that button's own work runs.
struct SimulatorActionLabel: View {
	let title: LocalizedStringKey
	let systemImage: String
	let isBusy: Bool

	var body: some View {
		Label {
			Text(title)
		} icon: {
			if isBusy {
				ProgressView()
					.controlSize(.small)
			} else {
				Image(systemName: systemImage)
			}
		}
	}
}
