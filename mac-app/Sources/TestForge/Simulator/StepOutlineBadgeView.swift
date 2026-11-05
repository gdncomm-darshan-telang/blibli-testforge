import SwiftUI

struct StepOutlineBadgeView: View {
	let number: Int
	let text: String

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.small) {
			Text("\(number)")
				.font(.caption.monospacedDigit().bold())
			Text(text)
				.font(.caption)
				.lineLimit(1)
		}
		.foregroundStyle(.white)
		.padding(.horizontal, TestForgeConstants.Spacing.medium)
		.frame(height: TestForgeConstants.Overlay.badgeHeight)
		.frame(maxWidth: TestForgeConstants.Overlay.badgeMaxWidth, alignment: .leading)
		.fixedSize()
		.background(Color.accentColor, in: Capsule())
		.accessibilityIdentifier(TestForgeConstants.Accessibility.stepOutlineBadge)
	}
}
