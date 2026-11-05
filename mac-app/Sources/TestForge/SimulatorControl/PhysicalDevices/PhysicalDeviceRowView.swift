import SwiftUI

struct PhysicalDeviceRowView: View {
	let row: PhysicalDeviceRowModel

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: row.isConnected ? "iphone.gen3.radiowaves.left.and.right" : "iphone.gen3")
				.foregroundStyle(row.isConnected ? Color.accentColor : Color.secondary)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(row.name)
					.font(.callout.weight(.semibold))
				Text(row.detailText)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			Spacer(minLength: 0)
			Text(row.stateText)
				.font(.caption)
				.foregroundStyle(row.isConnected ? .primary : .secondary)
		}
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.physicalDeviceRowPrefix + row.id)
	}
}
