import SwiftUI

struct TestCaseProofBadgeView: View {
	let badge: TestCaseProofBadge

	var body: some View {
		HStack(spacing: TestForgeConstants.Tests.proofBadgeSpacing) {
			Image(systemName: badge.systemImage)
			if let countText = badge.countText {
				Text(countText)
					.font(.caption.monospacedDigit())
			}
		}
		.foregroundStyle(.secondary)
		.help(badge.helpText)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text(badge.helpText))
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsProofBadgePrefix + badge.id)
	}
}
