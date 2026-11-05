import SwiftUI

/// D-192: the session's live line — what Claude is doing now, steps so far, cost and model.
struct ClaudeActivityStripView: View {
	let activity: ClaudeActivityModel

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			if activity.isWorking {
				ProgressView()
					.controlSize(.small)
			}
			Label(activity.activityText, systemImage: activity.systemImage)
				.font(.callout.weight(.medium))
				.lineLimit(1)
				.truncationMode(.tail)
				.accessibilityIdentifier(ClaudeConstants.Accessibility.activityText)
			Spacer()
			Text(activity.stepsText)
				.font(.caption)
				.foregroundStyle(.secondary)
			Text(activity.costText)
				.font(.caption.monospacedDigit())
				.foregroundStyle(.secondary)
				.help("Claude usage this session has cost so far")
			if let modelText = activity.modelText {
				Text(modelText)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
		.padding(.horizontal, TestForgeConstants.Spacing.medium)
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.background(.background.secondary)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(ClaudeConstants.Accessibility.activityStrip)
		.tutorialAnchor(.claudeActivityStrip)
	}
}
