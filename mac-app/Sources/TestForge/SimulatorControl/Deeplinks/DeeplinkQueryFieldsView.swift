import SwiftUI

struct DeeplinkQueryActions {
	let add: () -> Void
	let change: (DeeplinkQueryItem) -> Void
	let remove: (UUID) -> Void
}

struct DeeplinkQueryFieldsContent {
	let rows: [DeeplinkQueryRowContent]
	let keyChoices: [DeeplinkQueryKeyChoice]
	let preview: String?
}

/// Query parameters added to the link, whether it was built from a screen or typed.
struct DeeplinkQueryFieldsView: View {
	let content: DeeplinkQueryFieldsContent
	let actions: DeeplinkQueryActions

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			ForEach(content.rows) { row in
				DeeplinkQueryRowView(content: row, keyChoices: content.keyChoices, actions: actions)
			}
			Button("Add query parameter", systemImage: "plus.circle", action: actions.add)
				.buttonStyle(.borderless)
				.help("Adds ?name=value to the link. Values are URL-encoded for you.")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkQueryAdd)
			if let preview = content.preview {
				Label(preview, systemImage: "arrow.turn.down.right")
					.font(.caption.monospaced())
					.foregroundStyle(.secondary)
					.textSelection(.enabled)
					.help("The link that Open in app and Save use")
					.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkQueryPreview)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkQueryFields)
	}
}
