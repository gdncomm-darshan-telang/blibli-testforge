import SwiftUI

/// Distances from the selected element to whatever the pointer is over, like holding Option in Figma.
struct MeasureComparisonSectionView: View {
	let comparison: MeasureComparison?

	var body: some View {
		Section("Compared with (hover)") {
			if let comparison {
				Text(comparison.title)
					.font(.callout.weight(.medium))
					.lineLimit(2)
				ForEach(comparison.gaps) { gap in
					LabeledContent(gap.edge.title, value: MeasureFormatting.points(gap.distance))
				}
			} else {
				Text("Point at another element, a parent or empty space to measure to it.")
					.font(.callout)
					.foregroundStyle(.secondary)
			}
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.measureComparisonSection)
	}
}
