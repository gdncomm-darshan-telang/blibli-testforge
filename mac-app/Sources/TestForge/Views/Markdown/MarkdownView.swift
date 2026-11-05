import SwiftUI

/// Renders Markdown inside the app (D-176): parsed once per text, drawn natively, local images shown inline.
struct MarkdownView: View {
	let blocks: [MarkdownBlockItem]

	var body: some View {
		ScrollView {
			LazyVStack(alignment: .leading, spacing: MarkdownConstants.blockSpacing) {
				ForEach(blocks) { item in
					MarkdownBlockView(block: item.block)
						.frame(maxWidth: .infinity, alignment: .leading)
						.accessibilityIdentifier(MarkdownConstants.Accessibility.blockPrefix + String(item.id))
				}
			}
			.padding(TestForgeConstants.Spacing.extraLarge)
			.frame(maxWidth: MarkdownConstants.contentMaxWidth, alignment: .leading)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(MarkdownConstants.Accessibility.viewer)
	}
}
