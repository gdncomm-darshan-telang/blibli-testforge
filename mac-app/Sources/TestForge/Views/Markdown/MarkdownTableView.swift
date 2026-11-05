import SwiftUI

struct MarkdownTableView: View {
	let table: MarkdownTable

	var body: some View {
		ScrollView(.horizontal) {
			Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
				GridRow {
					ForEach(Array(table.header.enumerated()), id: \.offset) { _, cell in
						cellView(cell, isHeader: true)
					}
				}
				.background(Color.secondary.opacity(MarkdownConstants.backgroundOpacity))
				ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
					Divider()
					GridRow {
						ForEach(Array(table.header.indices), id: \.self) { column in
							cellView(row[safe: column] ?? "", isHeader: false)
						}
					}
				}
			}
			.overlay {
				RoundedRectangle(cornerRadius: MarkdownConstants.codeCornerRadius)
					.strokeBorder(.separator)
			}
		}
	}

	private func cellView(_ text: String, isHeader: Bool) -> some View {
		MarkdownInlineText(text: text)
			.font(isHeader ? .callout.weight(.semibold) : .callout)
			.frame(minWidth: MarkdownConstants.tableMinColumnWidth, alignment: .leading)
			.padding(MarkdownConstants.tableCellPadding)
	}
}
