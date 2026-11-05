import SwiftUI

struct NetworkHeldCallRowView: View {
	let held: HeldCallModel
	let index: Int

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: "hand.raised.fill")
				.foregroundStyle(.red)
			VStack(alignment: .leading, spacing: 0) {
				Text(held.endpoint)
					.font(.callout.monospaced().bold())
					.lineLimit(1)
					.truncationMode(.middle)
				Text(held.detailText)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
					.truncationMode(.middle)
			}
		}
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.heldRowPrefix + String(index))
	}
}
