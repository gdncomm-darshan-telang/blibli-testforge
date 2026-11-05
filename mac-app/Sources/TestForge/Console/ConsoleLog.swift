import Foundation

enum ConsoleSource: String, CaseIterable, Identifiable {
	case server
	case app

	var id: String { rawValue }
}

struct ConsoleLine: Identifiable, Equatable {
	let id: Int
	let recordedAt: Date
	let source: ConsoleSource
	let text: String
}

protocol ConsoleLogging: AnyObject {
	func append(text: String, source: ConsoleSource)
}

/// The one raw-log buffer every part of the app writes to; the console section reads it.
final class ConsoleLog: ObservableObject, ConsoleLogging {
	@MainActor @Published private(set) var lines: [ConsoleLine] = []

	/// Oldest lines drop first so a long session doesn't grow memory without bound.
	private let maxLineCount = 5_000

	@MainActor private var nextLineId = 0

	func append(text: String, source: ConsoleSource) {
		Task { @MainActor in
			appendOnMain(text: text, source: source)
		}
	}

	@MainActor
	func clear() {
		lines.removeAll()
	}

	@MainActor
	private func appendOnMain(text: String, source: ConsoleSource) {
		let line = ConsoleLine(id: nextLineId, recordedAt: Date(), source: source, text: text)
		nextLineId += 1
		lines.append(line)
		let overflowCount = lines.count - maxLineCount
		if overflowCount > 0 {
			lines.removeFirst(overflowCount)
		}
	}
}
