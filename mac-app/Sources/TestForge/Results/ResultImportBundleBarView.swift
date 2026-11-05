import SwiftUI

struct ResultImportBundleBarView: View {
	let onImport: () -> Void

	var body: some View {
		HStack {
			Button {
				onImport()
			} label: {
				Label("Import bundle…", systemImage: "shippingbox.and.arrow.backward")
			}
			.help("Open a run bundle from someone else, add its recordings and mocks, and replay it without Claude")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsImportBundleButton)
			.tutorialAnchor(.resultsImportBundleButton)
			Spacer()
		}
		.padding(TestForgeConstants.Spacing.medium)
	}
}
