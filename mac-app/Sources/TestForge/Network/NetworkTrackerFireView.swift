import SwiftUI

/// One fire of the selected TRMS ID: when, where, what the contract found, and the payload it carried.
struct NetworkTrackerFireView: View {
	let fire: TrackerFireModel
	let index: Int

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text(fire.title)
				.font(.callout.monospaced().bold())
			Text(fire.detailText)
				.font(.caption)
				.foregroundStyle(.secondary)
			ForEach(fire.problems, id: \.self) { problem in
				Label(problem, systemImage: "exclamationmark.circle")
					.font(.caption)
					.foregroundStyle(.orange)
			}
			ScrollView {
				Text(fire.payload)
					.font(.caption.monospaced())
					.textSelection(.enabled)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			.frame(maxHeight: NetworkConsoleConstants.Trackers.payloadMaxHeight)
			.border(.quaternary)
		}
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.trackerFirePrefix + String(index))
	}
}
