import SwiftUI

struct PreparedCodeSummaryView: View {
	let current: PreparedCodeSummary?

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			if let current {
				Label {
					Text("Prepared: \(current.branch) @ \(current.snapshotId)")
						.font(.body.weight(.medium))
				} icon: {
					Image(systemName: current.hasAppChanged ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
						.foregroundStyle(current.hasAppChanged ? .orange : .green)
				}
				Text("\(current.title) — \(current.author) · \(current.changedFileCount) changed file(s)")
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(2)
				if let changedFile = current.changedAppFiles.first {
					Text("App code changed since: \(changedFile)")
						.font(.caption)
						.foregroundStyle(.orange)
						.textSelection(.enabled)
				}
			} else {
				Text("Nothing prepared yet. Tests run on a separate QA copy, never on your own working copy.")
					.font(.callout)
					.foregroundStyle(.secondary)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(TestForgeConstants.Spacing.medium)
		.background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: TestForgeConstants.Spacing.medium))
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.prepareCodeCurrent)
	}
}
