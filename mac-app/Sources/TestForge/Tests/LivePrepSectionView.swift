import SwiftUI

/// System prep for the run on show: what the TestForge is doing to get the phone ready, kept off the explained overlay.
struct LivePrepSectionView: View {
	let prep: LivePrepModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Label("System prep", systemImage: "gearshape.2")
				.font(.caption.weight(.semibold))
				.foregroundStyle(.secondary)
			ForEach(Array(prep.earlier.enumerated()), id: \.offset) { index, message in
				Label(message, systemImage: "checkmark")
					.font(.caption)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testsPrepEarlierPrefix + String(index))
			}
			if let current = prep.current {
				currentRow(message: current)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(TestForgeConstants.Spacing.medium)
		.help("What the TestForge does to get the phone ready. Viewers of a replay with explanations don't see this.")
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsPrepSection)
	}

	private func currentRow(message: String) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			ProgressView()
				.controlSize(.mini)
			Text(message)
				.font(.callout)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testsPrepCurrent)
			Spacer()
			if let since = prep.since {
				Text(since, style: .timer)
					.font(.caption.monospacedDigit())
					.foregroundStyle(.secondary)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testsPrepTimer)
			}
		}
	}
}
