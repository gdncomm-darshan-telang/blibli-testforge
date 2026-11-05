import SwiftUI

struct LiveStepRowView: View {
	let step: LiveStepRowModel

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			statusIcon
				.frame(width: TestForgeConstants.Tests.stepIconSize)
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(step.text)
					.font(.callout)
				if let reason = step.reason {
					Text(reason)
						.font(.caption)
						.foregroundStyle(.red)
				}
			}
			Spacer()
			if let durationText = step.durationText {
				Text(durationText)
					.font(.caption.monospacedDigit())
					.foregroundStyle(.secondary)
			}
		}
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsStepRowPrefix + String(step.id))
	}

	@ViewBuilder
	private var statusIcon: some View {
		switch step.status {
			case .working:
				ProgressView()
					.controlSize(.mini)
			case .done:
				Image(systemName: "checkmark.circle.fill")
					.foregroundStyle(.green)
			case .failed:
				Image(systemName: "xmark.circle.fill")
					.foregroundStyle(.red)
			case .skipped:
				Image(systemName: "minus.circle")
					.foregroundStyle(.secondary)
		}
	}
}
