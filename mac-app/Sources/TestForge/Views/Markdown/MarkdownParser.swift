import Foundation

/// A small CommonMark subset: headings, paragraphs, lists, quotes, fenced code, pipe tables, image lines and rules.
/// Enough for the reports the TestForge writes; anything else reads as a paragraph.
enum MarkdownParser {
	private static let imagePattern = try? Regex<(Substring, Substring, Substring)>(#"!\[([^\]]*)\]\(([^)\s]+)\)\s*"#)
	private static let orderedPattern = try? Regex(#"\d{1,3}[.)]\s"#)

	static func parse(_ text: String) -> [MarkdownBlockItem] {
		var reader = LineReader(lines: text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n"))
		var blocks: [MarkdownBlock] = []
		while let line = reader.peek() {
			let trimmed = line.trimmingCharacters(in: .whitespaces)
			if trimmed.isEmpty {
				reader.advance()
			} else if trimmed.hasPrefix("```") {
				blocks.append(.code(reader.fencedCode()))
			} else if let heading = heading(in: trimmed) {
				reader.advance()
				blocks.append(heading)
			} else if trimmed == "---" || trimmed == "***" {
				reader.advance()
				blocks.append(.rule)
			} else if trimmed.hasPrefix("|") {
				blocks.append(reader.table())
			} else if let images = images(in: trimmed, startId: blocks.count * 100) {
				reader.advance()
				blocks.append(.images(images))
			} else if trimmed.hasPrefix("> ") || trimmed == ">" {
				blocks.append(.quote(reader.prefixedLines { quoteText(of: $0) }.joined(separator: "\n")))
			} else if bulletText(of: trimmed) != nil {
				blocks.append(.bulletList(reader.prefixedLines { bulletText(of: $0) }))
			} else if orderedText(of: trimmed) != nil {
				blocks.append(.orderedList(reader.prefixedLines { orderedText(of: $0) }))
			} else {
				blocks.append(.paragraph(reader.paragraph()))
			}
		}
		return blocks.enumerated().map { MarkdownBlockItem(id: $0.offset, block: $0.element) }
	}

	/// Splits a table row on unescaped pipes; `\|` stays a literal pipe in the cell.
	static func cells(of line: String) -> [String] {
		var trimmed = line.trimmingCharacters(in: .whitespaces)
		if trimmed.hasPrefix("|") {
			trimmed.removeFirst()
		}
		if trimmed.hasSuffix("|") && !trimmed.hasSuffix("\\|") {
			trimmed.removeLast()
		}
		var cells: [String] = []
		var current = ""
		var isEscaped = false
		for character in trimmed {
			if isEscaped {
				current.append(character == "|" ? "|" : "\\\(character)")
				isEscaped = false
			} else if character == "\\" {
				isEscaped = true
			} else if character == "|" {
				cells.append(current.trimmingCharacters(in: .whitespaces))
				current = ""
			} else {
				current.append(character)
			}
		}
		cells.append(current.trimmingCharacters(in: .whitespaces))
		return cells
	}

	static func isTableSeparator(_ line: String) -> Bool {
		let cells = cells(of: line)
		return !cells.isEmpty && cells.allSatisfy { cell in
			!cell.isEmpty && cell.allSatisfy { $0 == "-" || $0 == ":" }
		}
	}

	private static func heading(in line: String) -> MarkdownBlock? {
		let hashes = line.prefix { $0 == "#" }.count
		guard (1...6).contains(hashes),
			line.dropFirst(hashes).first == " "
		else {
			return nil
		}
		return .heading(level: hashes, text: String(line.dropFirst(hashes + 1)))
	}

	/// A line made only of `![alt](url)` images becomes an image row.
	private static func images(in line: String, startId: Int) -> [MarkdownImage]? {
		guard line.hasPrefix("![") else {
			return nil
		}
		guard let pattern = imagePattern else {
			return nil
		}
		var images: [MarkdownImage] = []
		var rest = Substring(line)
		while let match = try? pattern.prefixMatch(in: rest) {
			let address = String(match.output.2)
			let url = URL(string: address) ?? URL(string: address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
			images.append(MarkdownImage(id: startId + images.count, alt: String(match.output.1), url: url))
			rest = rest[match.range.upperBound...]
		}
		return rest.isEmpty && !images.isEmpty ? images : nil
	}

	static func bulletText(of line: String) -> String? {
		for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
			return String(line.dropFirst(marker.count))
		}
		return nil
	}

	static func orderedText(of line: String) -> String? {
		guard let pattern = orderedPattern,
			let match = try? pattern.prefixMatch(in: line)
		else {
			return nil
		}
		return String(line[match.range.upperBound...])
	}

	static func quoteText(of line: String) -> String? {
		if line == ">" {
			return ""
		}
		return line.hasPrefix("> ") ? String(line.dropFirst(2)) : nil
	}

	/// Lines that start another block end a paragraph.
	static func startsBlock(_ line: String) -> Bool {
		line.hasPrefix("#") || line.hasPrefix("```") || line.hasPrefix("|") || line.hasPrefix("![") || line.hasPrefix(">")
			|| line == "---" || bulletText(of: line) != nil || orderedText(of: line) != nil
	}
}

private struct LineReader {
	let lines: [String]
	var index = 0

	func peek() -> String? {
		lines[safe: index]
	}

	mutating func advance() {
		index += 1
	}

	mutating func fencedCode() -> String {
		advance()
		var code: [String] = []
		while let line = peek(), !line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
			code.append(line)
			advance()
		}
		advance()
		return code.joined(separator: "\n")
	}

	mutating func table() -> MarkdownBlock {
		var rows: [[String]] = []
		while let line = peek(), line.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
			if !MarkdownParser.isTableSeparator(line) {
				rows.append(MarkdownParser.cells(of: line))
			}
			advance()
		}
		guard let header = rows.first else {
			return .paragraph("")
		}
		return .table(MarkdownTable(header: header, rows: Array(rows.dropFirst())))
	}

	mutating func prefixedLines(_ text: (String) -> String?) -> [String] {
		var items: [String] = []
		while let line = peek(), let item = text(line.trimmingCharacters(in: .whitespaces)) {
			items.append(item)
			advance()
		}
		return items
	}

	mutating func paragraph() -> String {
		var parts: [String] = []
		while let line = peek() {
			let trimmed = line.trimmingCharacters(in: .whitespaces)
			if trimmed.isEmpty || (!parts.isEmpty && MarkdownParser.startsBlock(trimmed)) {
				break
			}
			parts.append(trimmed)
			advance()
		}
		return parts.joined(separator: "\n")
	}
}
