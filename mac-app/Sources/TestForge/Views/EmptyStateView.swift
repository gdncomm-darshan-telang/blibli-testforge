import SwiftUI

struct EmptyStateContent {
	let title: LocalizedStringResource
	let systemImage: String
	let message: LocalizedStringResource
}

/// Used instead of `ContentUnavailableView`, whose message never wraps and was clipped in the 280-pt live-steps pane.
struct EmptyStateView<Actions: View>: View {
	let content: EmptyStateContent
	@ViewBuilder let actions: () -> Actions

	var body: some View {
		VStack(spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: content.systemImage)
				.font(.largeTitle)
				.foregroundStyle(.secondary)
			Text(content.title)
				.font(.title3.weight(.semibold))
			Text(content.message)
				.font(.callout)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
			actions()
		}
		.padding(TestForgeConstants.Spacing.large)
		.frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.emptyState)
	}
}

extension EmptyStateView where Actions == EmptyView {
	init(content: EmptyStateContent) {
		self.init(content: content) {
			EmptyView()
		}
	}
}
