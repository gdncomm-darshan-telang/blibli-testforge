import SwiftUI

struct MarkdownBlockView: View {
	let block: MarkdownBlock

	var body: some View {
		switch block {
			case .heading(let level, let text):
				MarkdownInlineText(text: text)
					.font(Self.headingFont(level: level))
					.padding(.top, level <= 2 ? MarkdownConstants.blockSpacing : 0)
			case .paragraph(let text):
				MarkdownInlineText(text: text)
			case .bulletList(let items):
				listView(items: items) { _ in "•" }
			case .orderedList(let items):
				listView(items: items) { index in "\(index + 1)." }
			case .quote(let text):
				quoteView(text: text)
			case .code(let code):
				Text(code)
					.font(.system(.callout, design: .monospaced))
					.textSelection(.enabled)
					.padding(MarkdownConstants.tableCellPadding)
					.frame(maxWidth: .infinity, alignment: .leading)
					.background(Color.secondary.opacity(MarkdownConstants.backgroundOpacity), in: codeShape)
			case .table(let table):
				MarkdownTableView(table: table)
			case .images(let images):
				imageRow(images)
			case .rule:
				Divider()
		}
	}

	private var codeShape: RoundedRectangle {
		RoundedRectangle(cornerRadius: MarkdownConstants.codeCornerRadius)
	}

	private func listView(items: [String], marker: @escaping (Int) -> String) -> some View {
		VStack(alignment: .leading, spacing: MarkdownConstants.listItemSpacing) {
			ForEach(Array(items.enumerated()), id: \.offset) { index, item in
				HStack(alignment: .firstTextBaseline, spacing: 0) {
					Text(marker(index))
						.foregroundStyle(.secondary)
						.frame(width: MarkdownConstants.bulletWidth, alignment: .leading)
					MarkdownInlineText(text: item)
				}
			}
		}
	}

	private func quoteView(text: String) -> some View {
		HStack(alignment: .top, spacing: MarkdownConstants.tableCellPadding) {
			Rectangle()
				.fill(Color.accentColor)
				.frame(width: MarkdownConstants.quoteBarWidth)
			MarkdownInlineText(text: text)
				.foregroundStyle(.secondary)
		}
		.fixedSize(horizontal: false, vertical: true)
	}

	private func imageRow(_ images: [MarkdownImage]) -> some View {
		ScrollView(.horizontal) {
			HStack(alignment: .top, spacing: MarkdownConstants.blockSpacing) {
				ForEach(images) { image in
					MarkdownImageView(image: image)
				}
			}
		}
	}

	private static func headingFont(level: Int) -> Font {
		switch level {
			case 1:
				return .title.weight(.bold)
			case 2:
				return .title2.weight(.semibold)
			case 3:
				return .title3.weight(.semibold)
			default:
				return .headline
		}
	}
}
