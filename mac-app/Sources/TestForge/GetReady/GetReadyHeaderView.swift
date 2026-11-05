import SwiftUI

struct GetReadyHeaderView: View {
	let headline: String
	let progressFraction: Double

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Text(headline)
				.font(.title2.weight(.semibold))
			ProgressView(value: progressFraction)
				.progressViewStyle(.linear)
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.getReadyHeader)
		.tutorialAnchor(.getReadyHeader)
	}
}
