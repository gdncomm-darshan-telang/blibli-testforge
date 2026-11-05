import SwiftUI

/// D-163: which mocked response each case ran with, so a case can be set up again without Claude.
struct BundleCaseMockListView: View {
	let rows: [BundleCaseMockRowModel]
	let armMessage: String?
	let onArm: (String) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text("Mocked responses per case")
				.font(.headline)
			ScrollView {
				LazyVStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
					ForEach(rows) { row in
						BundleCaseMockRowView(row: row, onArm: onArm)
					}
				}
			}
			.frame(maxHeight: TestForgeConstants.Results.bundleMockListMaxHeight)
			if let armMessage {
				Text(armMessage)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsBundleMockList)
	}
}
