import SwiftUI

/// One `GridRow`; it lives inside `RunComparisonView`'s grid so the columns line up.
struct ComparisonRowView: View {
	let row: ComparisonRowModel

	var body: some View {
		GridRow(alignment: .firstTextBaseline) {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(row.id)
					.font(.callout.monospaced().weight(.semibold))
				Text(row.scenario)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(2)
			}
			Text(row.baseText)
				.font(.callout)
				.lineLimit(2)
				.frame(width: TestForgeConstants.Reports.verdictColumnWidth, alignment: .leading)
			Text(row.headText)
				.font(.callout)
				.lineLimit(2)
				.frame(width: TestForgeConstants.Reports.verdictColumnWidth, alignment: .leading)
			VerdictBadgeView(text: row.changeText, tone: row.changeTone)
				.frame(width: TestForgeConstants.Reports.changeColumnWidth, alignment: .leading)
		}
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.reportsComparisonRowPrefix + row.id)
	}
}
