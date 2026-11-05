import SwiftUI

/// Inline Markdown (bold, italic, code, links) for one block's text; falls back to the raw text when it doesn't parse.
struct MarkdownInlineText: View {
	let text: String

	var body: some View {
		Text(Self.attributed(text))
			.textSelection(.enabled)
			.fixedSize(horizontal: false, vertical: true)
	}

	static func attributed(_ text: String) -> AttributedString {
		let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
		return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
	}
}
