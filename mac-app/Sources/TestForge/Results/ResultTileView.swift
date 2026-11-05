import SwiftUI

struct ResultTileView: View {
	let tile: ResultTileModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text(tile.title)
				.font(.caption)
				.foregroundStyle(.secondary)
			Text(tile.value)
				.font(.title3.monospacedDigit().weight(.semibold))
				.foregroundStyle(toneColor)
		}
		.padding(TestForgeConstants.Spacing.medium)
		.frame(minWidth: TestForgeConstants.Results.tileMinWidth, alignment: .leading)
		.background(
			toneColor.opacity(TestForgeConstants.Results.tileBackgroundOpacity),
			in: RoundedRectangle(cornerRadius: TestForgeConstants.Results.tileCornerRadius)
		)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsTilePrefix + tile.id)
	}

	private var toneColor: Color {
		switch tile.tone {
			case .passed:
				return .green
			case .failed:
				return .red
			case .neutral:
				return .orange
			case .notRun:
				return .primary
		}
	}
}
