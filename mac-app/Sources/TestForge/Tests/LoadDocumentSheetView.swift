import SwiftUI

struct LoadDocumentSheetView: View {
	let onLoad: (String) -> Void
	let onCancel: () -> Void
	@State private var source: String

	init(initialSource: String, onLoad: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
		self.onLoad = onLoad
		self.onCancel = onCancel
		_source = State(initialValue: initialSource)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			Text("Load test document")
				.font(.headline)
			Text("Paste the Confluence page link, or the path to a Markdown or CSV file. The page is only read, never changed.")
				.font(.callout)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
			TextField("https://…/pages/123456 or /path/to/cases.md", text: $source)
				.textFieldStyle(.roundedBorder)
				.onSubmit {
					onLoad(source)
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.loadSheetField)
			HStack {
				Spacer()
				Button("Cancel", role: .cancel) {
					onCancel()
				}
				.keyboardShortcut(.cancelAction)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.loadSheetCancel)
				Button("Load") {
					onLoad(source)
				}
				.keyboardShortcut(.defaultAction)
				.disabled(source.trimmingCharacters(in: .whitespaces).isEmpty)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.loadSheetConfirm)
			}
		}
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(width: TestForgeConstants.Tests.loadSheetWidth)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.loadSheet)
	}
}
