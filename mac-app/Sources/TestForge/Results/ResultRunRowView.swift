import SwiftUI

struct ResultRunRowView: View {
	let row: ResultRunRowModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack(spacing: TestForgeConstants.Spacing.small) {
				Text(row.title)
					.font(.body.weight(.semibold))
				Spacer()
				statusIcon
			}
			Text(row.subtitle)
				.font(.caption.monospaced())
				.foregroundStyle(.secondary)
				.lineLimit(1)
				.truncationMode(.middle)
			Text(row.countsText)
				.font(.callout)
			Text(row.reviewText)
				.font(.caption)
				.foregroundStyle(row.isValidated ? .green : .secondary)
		}
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsRunRowPrefix + row.id)
	}

	@ViewBuilder
	private var statusIcon: some View {
		if row.isRunning {
			ProgressView()
				.controlSize(.small)
				.accessibilityLabel("Running")
		} else if row.isValidated {
			Image(systemName: "checkmark.seal.fill")
				.foregroundStyle(.green)
				.accessibilityLabel("Validated")
		}
	}
}
