import SwiftUI

struct VerifyCaseRowView: View {
	let entry: VerifyCase

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				Text(entry.caseId)
					.font(.callout.monospaced().weight(.semibold))
				Text(entry.macroName)
					.lineLimit(1)
			}
			Text(entry.filesText)
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(2)
		}
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.verifyCaseRowPrefix + entry.caseId)
	}
}
