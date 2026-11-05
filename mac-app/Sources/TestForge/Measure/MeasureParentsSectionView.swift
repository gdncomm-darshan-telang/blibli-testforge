import SwiftUI

/// The selected element's inset inside each parent, innermost first, out to the screen.
struct MeasureParentsSectionView: View {
	let enclosures: [MeasureEnclosure]

	var body: some View {
		Section("Inside each parent (points)") {
			ForEach(enclosures) { enclosure in
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
					Text(enclosure.title)
						.font(.callout.weight(.medium))
						.lineLimit(1)
					Text(MeasureFormatting.insetsText(enclosure.insets))
						.font(.callout.monospacedDigit())
						.foregroundStyle(.secondary)
						.textSelection(.enabled)
				}
				.accessibilityElement(children: .combine)
			}
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.measureParentsSection)
	}
}
