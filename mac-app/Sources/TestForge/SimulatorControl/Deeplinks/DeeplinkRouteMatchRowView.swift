import SwiftUI

struct DeeplinkRouteMatchRowView: View {
	let route: DeeplinkRoute
	let onSelect: () -> Void

	var body: some View {
		Button(action: onSelect) {
			VStack(alignment: .leading, spacing: 2) {
				Text(route.description)
				Text(route.template)
					.font(.caption.monospaced())
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.horizontal, TestForgeConstants.Spacing.medium)
			.padding(.vertical, TestForgeConstants.Spacing.small)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkRouteMatchPrefix + route.id)
	}
}
