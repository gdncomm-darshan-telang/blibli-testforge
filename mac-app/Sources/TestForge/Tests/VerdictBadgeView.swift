import SwiftUI

struct VerdictBadgeView: View {
	let text: String
	let tone: VerdictTone

	var body: some View {
		Text(text)
			.font(.caption.weight(.semibold))
			.foregroundStyle(toneColor)
			.padding(.horizontal, TestForgeConstants.Spacing.medium)
			.padding(.vertical, TestForgeConstants.Tests.badgeVerticalPadding)
			.background(toneColor.opacity(TestForgeConstants.Tests.badgeBackgroundOpacity), in: Capsule())
			.accessibilityIdentifier(TestForgeConstants.Accessibility.verdictBadge)
	}

	private var toneColor: Color {
		switch tone {
			case .passed:
				return .green
			case .failed:
				return .red
			case .neutral:
				return .orange
			case .notRun:
				return .secondary
		}
	}
}
