import SwiftUI

struct FlowTreeRowView: View {
	let node: FlowTreeNode
	let isCurrent: Bool

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: node.isLink ? "arrow.turn.down.right" : "rectangle.portrait")
				.foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
			VStack(alignment: .leading, spacing: 0) {
				Text(node.name)
					.fontWeight(isCurrent ? .semibold : .regular)
					.foregroundStyle(node.isLink ? .secondary : .primary)
				if let viaText = node.viaText {
					Text(viaText)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}
			}
			if isCurrent {
				Spacer()
				Image(systemName: "location.fill")
					.font(.caption)
					.foregroundStyle(Color.accentColor)
					.help("The Simulator is on this screen")
			}
		}
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.flowMapNodePrefix + node.id)
	}
}
