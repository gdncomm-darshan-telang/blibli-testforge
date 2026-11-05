import SwiftUI

struct BundleImportSummaryView: View {
	let model: BundleImportModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Text(model.title)
				.font(.headline)
				.lineLimit(2)
			Grid(alignment: .leading, horizontalSpacing: TestForgeConstants.Spacing.medium, verticalSpacing: TestForgeConstants.Spacing.small) {
				ForEach(model.facts) { fact in
					GridRow {
						Text(fact.label)
							.foregroundStyle(.secondary)
						Text(fact.value)
							.textSelection(.enabled)
					}
					.font(.callout)
				}
			}
			Label(model.codeMessage, systemImage: model.isCodeMatch ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
				.font(.callout)
				.foregroundStyle(model.isCodeMatch ? .green : .orange)
			if let conflictText = model.conflictText {
				Label(conflictText, systemImage: "arrow.triangle.branch")
					.font(.callout)
			}
			ForEach(model.warnings, id: \.self) { warning in
				Label(warning, systemImage: "info.circle")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
	}
}
