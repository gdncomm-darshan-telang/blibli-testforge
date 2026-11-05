import SwiftUI

struct BatchReportRowView: View {
	let row: BatchReportRowModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack(spacing: TestForgeConstants.Spacing.small) {
				statusIcon
				Text(row.name)
					.font(.body.weight(.semibold))
					.lineLimit(1)
			}
			Text(row.dateText)
				.font(.caption)
				.foregroundStyle(.secondary)
			Text(row.progressText)
				.font(.caption)
				.foregroundStyle(row.hasFailures ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
				.lineLimit(1)
		}
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(ReportsConstants.Accessibility.batchRowPrefix + row.id)
	}

	@ViewBuilder
	private var statusIcon: some View {
		switch row.status {
			case .active:
				Image(systemName: "record.circle.fill")
					.foregroundStyle(.green)
					.accessibilityLabel("Active")
			case .paused:
				Image(systemName: "pause.circle.fill")
					.foregroundStyle(.orange)
					.accessibilityLabel("Paused")
			case .ended:
				Image(systemName: "archivebox")
					.foregroundStyle(.secondary)
					.accessibilityLabel("Ended")
		}
	}
}
