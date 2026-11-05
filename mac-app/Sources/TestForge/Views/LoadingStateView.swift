import SwiftUI

/// The one loading style (D-195): spinner and words, plus the elapsed time once the wait is long enough to wonder about.
struct LoadingStateView: View {
	let text: LocalizedStringKey
	@State private var startedAt = Date()

	var body: some View {
		VStack(spacing: TestForgeConstants.Spacing.small) {
			ProgressView()
				.controlSize(.small)
			Text(text)
				.font(.callout)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
			TimelineView(.periodic(from: startedAt, by: TestForgeConstants.Loading.tick)) { context in
				let elapsed = context.date.timeIntervalSince(startedAt)
				Text(elapsed >= TestForgeConstants.Loading.showElapsedAfter ? "\(Int(elapsed)) s" : " ")
					.font(.caption.monospacedDigit())
					.foregroundStyle(.tertiary)
			}
		}
		.frame(maxWidth: .infinity)
		.padding(TestForgeConstants.Spacing.medium)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.loadingState)
	}
}
