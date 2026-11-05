import SwiftUI

/// The selected rule's answers, the active one's body, and Edit — the editor opens on whichever answer is picked here.
struct NetworkVariantPreviewView: View {
	let rule: NetworkRuleRowModel
	let edit: (_ variantId: String) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Text(rule.endpoint)
				.font(.headline.monospaced())
				.textSelection(.enabled)
			ForEach(rule.variants) { variant in
				HStack(spacing: TestForgeConstants.Spacing.medium) {
					Image(systemName: variant.id == rule.activeVariantId ? "largecircle.fill.circle" : "circle")
						.foregroundStyle(variant.id == rule.activeVariantId ? Color.accentColor : .secondary)
					Text(variant.name)
						.font(.callout.bold())
					Text(variant.summary)
						.font(.caption)
						.foregroundStyle(.secondary)
					Spacer()
					Button("Edit", systemImage: "pencil") {
						edit(variant.id)
					}
					.disabled(!variant.isEditable)
					.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.editVariantButton + "_" + variant.name)
				}
			}
			Divider()
			ScrollView([.vertical, .horizontal]) {
				Text(activeBody)
					.font(.callout.monospaced())
					.textSelection(.enabled)
					.frame(maxWidth: .infinity, alignment: .topLeading)
			}
		}
		.padding(TestForgeConstants.Spacing.medium)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.variantPreview)
	}

	private var activeBody: String {
		guard let variant = rule.activeVariant else {
			return ""
		}
		return variant.body.isEmpty ? variant.summary : variant.body
	}
}
