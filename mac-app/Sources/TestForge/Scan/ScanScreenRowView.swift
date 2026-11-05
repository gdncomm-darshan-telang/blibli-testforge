import SwiftUI

struct ScanScreenRowView: View {
	let screen: ScanScreenRowModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text(screen.name)
				.font(.body.weight(.semibold))
			Label {
				Text(screen.detail)
			} icon: {
				if screen.hasWarning {
					Image(systemName: "exclamationmark.triangle")
						.foregroundStyle(.orange)
				}
			}
			.font(.caption)
			.foregroundStyle(.secondary)
		}
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.scanScreenRowPrefix + screen.id)
	}
}
