import SwiftUI

struct ResultCaseRowView: View {
	let row: ResultCaseRowModel

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(row.caseId)
					.font(.body.monospaced().weight(.semibold))
				Text(row.scenario)
					.font(.callout)
					.foregroundStyle(.secondary)
					.lineLimit(2)
				Text("\(row.ranAsText) · \(row.reviewText)")
					.font(.caption)
					.foregroundStyle(row.isReviewed ? .green : .secondary)
					.lineLimit(1)
			}
			Spacer()
			VerdictBadgeView(text: row.verdictText, tone: row.verdictTone)
		}
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsCaseRowPrefix + row.caseId)
	}
}
