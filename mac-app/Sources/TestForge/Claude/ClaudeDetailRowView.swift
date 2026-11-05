import SwiftUI

/// A tool call or result: one line, expandable to everything Claude sent or got back (D-147).
struct ClaudeDetailRowView: View {
	let summary: String
	let detail: String
	let symbolName: String
	let isError: Bool

	/// Details on (the section's switch) opens every row; the person can still fold one.
	let isInitiallyExpanded: Bool

	@State private var isExpanded = false

	var body: some View {
		DisclosureGroup(isExpanded: $isExpanded) {
			ScrollView {
				Text(detail)
					.font(.caption.monospaced())
					.textSelection(.enabled)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			.frame(maxHeight: ClaudeConstants.Transcript.detailMaxHeight)
		} label: {
			Label {
				Text(summary)
					.font(.callout.monospaced())
					.lineLimit(1)
					.truncationMode(.middle)
			} icon: {
				Image(systemName: symbolName)
			}
			.foregroundStyle(isError ? Color.red : Color.secondary)
		}
		.onAppear {
			isExpanded = isInitiallyExpanded
		}
		.onChange(of: isInitiallyExpanded) { _, isOn in
			isExpanded = isOn
		}
	}
}
