import SwiftUI

struct BranchHistoryRowView: View {
	let row: BranchRowModel

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: "circle.fill")
				.font(.caption2)
				.foregroundStyle(row.tone == .passed ? .green : .red)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(row.id)
					.font(.body.monospaced().weight(.semibold))
					.lineLimit(1)
					.truncationMode(.middle)
				Text(row.detail)
					.font(.caption)
					.foregroundStyle(.secondary)
				Text(row.runCountText)
					.font(.caption)
					.foregroundStyle(.tertiary)
			}
		}
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.reportsBranchRowPrefix + row.id)
	}
}
