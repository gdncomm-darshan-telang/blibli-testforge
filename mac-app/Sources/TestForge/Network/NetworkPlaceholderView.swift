import SwiftUI

/// What a section shows when it has no content: loading, empty (with a hint), or failed (with the server's words).
struct NetworkPlaceholderView: View {
	let phase: NetworkPlaceholderPhase

	var body: some View {
		VStack(spacing: TestForgeConstants.Spacing.medium) {
			switch phase {
				case .loading:
					ProgressView()
						.controlSize(.small)
				case .empty(let hint):
					Image(systemName: "tray")
						.foregroundStyle(.secondary)
					Text(hint)
						.foregroundStyle(.secondary)
				case .failed(let message):
					Image(systemName: "exclamationmark.triangle")
						.foregroundStyle(.orange)
					Text(message)
						.foregroundStyle(.secondary)
						.textSelection(.enabled)
			}
		}
		.multilineTextAlignment(.center)
		.padding(TestForgeConstants.Spacing.large)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.placeholder)
	}
}

enum NetworkPlaceholderPhase: Equatable {
	case loading
	case empty(String)
	case failed(String)

	/// Nil when the state has content, so callers show the content instead.
	init?<Content>(state: NetworkSectionState<Content>) {
		switch state {
			case .notLoaded, .loading:
				self = .loading
			case .empty(let hint):
				self = .empty(hint)
			case .failed(let message):
				self = .failed(message)
			case .loaded:
				return nil
		}
	}
}
