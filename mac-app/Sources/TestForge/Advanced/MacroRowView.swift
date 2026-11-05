import SwiftUI

struct MacroRowView: View {
	let row: MacroRowModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack(spacing: TestForgeConstants.Spacing.small) {
				Text(row.name)
					.font(.callout.weight(.medium))
					.lineLimit(2)
				Spacer()
				if row.isUsingMocks {
					Image(systemName: "theatermasks")
						.foregroundStyle(.secondary)
						.help("Uses network mocks")
				}
			}
			Text(row.subtitle)
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(1)
		}
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.recordedStepsRowPrefix + row.id)
	}
}
