import SwiftUI

struct RunComparisonView: View {
	let state: RunComparisonState

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Text("What changed")
				.font(.title3.weight(.semibold))
			content
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.reportsComparison)
		.tutorialAnchor(.reportsComparison)
	}

	@ViewBuilder
	private var content: some View {
		switch state {
			case .idle:
				EmptyView()
			case .loading:
				LoadingStateView(text: "Comparing…")
			case .failed(let message):
				Label(message, systemImage: "exclamationmark.triangle")
					.foregroundStyle(.secondary)
			case .loaded(let comparison):
				loadedContent(comparison: comparison)
		}
	}

	private func loadedContent(comparison: RunComparisonModel) -> some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Text(comparison.title)
				.font(.callout)
				.foregroundStyle(.secondary)
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				ForEach(comparison.chips) { chip in
					VerdictBadgeView(text: chip.title, tone: chip.tone)
				}
			}
			if !comparison.rows.isEmpty {
				comparisonGrid(rows: comparison.rows)
			}
		}
	}

	private func comparisonGrid(rows: [ComparisonRowModel]) -> some View {
		Grid(alignment: .leading, horizontalSpacing: TestForgeConstants.Spacing.large, verticalSpacing: TestForgeConstants.Spacing.medium) {
			GridRow {
				Text("Test")
				Text("Other run")
				Text("This run")
				Text("Change")
			}
			.font(.caption.weight(.semibold))
			.foregroundStyle(.secondary)
			Divider()
			ForEach(rows) { row in
				ComparisonRowView(row: row)
			}
		}
	}
}
