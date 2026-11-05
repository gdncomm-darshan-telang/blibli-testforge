import SwiftUI

struct ResultOverrideHistoryRowView: View {
	let row: CaseResultOverrideHistoryRow

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				Text(row.changeText)
					.font(.callout.weight(.semibold))
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideHistoryChange)
				Text(row.detailText)
					.font(.caption)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideHistoryDetail)
			}
			Text(row.reason)
				.font(.callout)
				.textSelection(.enabled)
				.fixedSize(horizontal: false, vertical: true)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideHistoryReason)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideHistoryRow)
	}
}
