import SwiftUI

/// "Needs Claude ✓ / ✗" under a workflow step (D-148), with a note when it's only partly true.
struct OnboardingClaudeMarkerView: View {
	let needsClaude: Bool
	let note: String?

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.small) {
			Label {
				Text("Needs Claude")
			} icon: {
				Image(systemName: needsClaude ? "checkmark.circle.fill" : "xmark.circle.fill")
					.foregroundStyle(needsClaude ? Color.green : Color.secondary)
			}
			.font(.caption.bold())
			if let note {
				Text(note)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
		.padding(.horizontal, TestForgeConstants.Spacing.medium)
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.background(
			Capsule()
				.fill(.quaternary.opacity(OnboardingConstants.Layout.surfaceOpacity))
		)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(OnboardingConstants.Accessibility.claudeMarkerPrefix + (needsClaude ? "yes" : "no"))
	}
}
