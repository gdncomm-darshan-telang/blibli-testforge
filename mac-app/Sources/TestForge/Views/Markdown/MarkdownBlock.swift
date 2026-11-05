import Foundation

struct MarkdownImage: Equatable, Identifiable {
	let id: Int
	let alt: String
	let url: URL?
}

struct MarkdownTable: Equatable {
	let header: [String]
	let rows: [[String]]
}

/// The block kinds the in-app viewer draws (D-176); inline formatting stays in the text and is rendered by SwiftUI.
enum MarkdownBlock: Equatable {
	case heading(level: Int, text: String)
	case paragraph(String)
	case bulletList([String])
	case orderedList([String])
	case quote(String)
	case code(String)
	case table(MarkdownTable)
	case images([MarkdownImage])
	case rule
}

struct MarkdownBlockItem: Equatable, Identifiable {
	let id: Int
	let block: MarkdownBlock
}
