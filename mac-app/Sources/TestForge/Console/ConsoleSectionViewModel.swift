import Combine
import Foundation

enum ConsoleFilter: String, CaseIterable, Identifiable {
	case all
	case server
	case app

	var id: String { rawValue }

	var title: LocalizedStringResource {
		switch self {
			case .all:
				return "All"
			case .server:
				return "Server"
			case .app:
				return "App"
		}
	}

	var source: ConsoleSource? {
		switch self {
			case .all:
				return nil
			case .server:
				return .server
			case .app:
				return .app
		}
	}
}

/// Filters and searches the raw console lines; R3 adds the Claude · Phone · Build · Fake data sources.
final class ConsoleSectionViewModel: ObservableObject {
	@MainActor @Published var filter: ConsoleFilter = .all
	@MainActor @Published var searchText = ""
	@MainActor @Published private(set) var visibleLines: [ConsoleLine] = []

	private let log: ConsoleLog
	private let copyToPasteboard: (String) -> Void
	private var cancellables = Set<AnyCancellable>()

	@MainActor
	init(log: ConsoleLog, copyToPasteboard: @escaping (String) -> Void) {
		self.log = log
		self.copyToPasteboard = copyToPasteboard
		observeLines()
	}

	deinit {
		cancellables.forEach { $0.cancel() }
	}

	@MainActor
	func copyVisibleLines() {
		let text = visibleLines.map { "[\($0.source.rawValue)] \($0.text)" }.joined(separator: "\n")
		copyToPasteboard(text)
	}

	@MainActor
	func clear() {
		log.clear()
	}

	@MainActor
	private func observeLines() {
		log.$lines
			.combineLatest($filter, $searchText)
			.receive(on: DispatchQueue.main)
			.sink { [weak self] lines, filter, searchText in
				self?.visibleLines = Self.filterLines(lines: lines, filter: filter, searchText: searchText)
			}
			.store(in: &cancellables)
	}

	private static func filterLines(lines: [ConsoleLine], filter: ConsoleFilter, searchText: String) -> [ConsoleLine] {
		let query = searchText.trimmingCharacters(in: .whitespaces)
		return lines.filter { line in
			let isSourceMatch = filter.source == nil || line.source == filter.source
			let isTextMatch = query.isEmpty || line.text.localizedCaseInsensitiveContains(query)
			return isSourceMatch && isTextMatch
		}
	}
}
