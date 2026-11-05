import Foundation

/// Each Network console section's own state machine — shared shape, never a shared instance.
enum NetworkSectionState<Content: Equatable>: Equatable {
	case notLoaded
	case loading
	case loaded(Content)
	case empty(String)
	case failed(String)

	var content: Content? {
		guard case .loaded(let content) = self else {
			return nil
		}
		return content
	}
}

/// What every section tells the page: something changed (refresh all), and a line to show the person.
struct NetworkSectionEvents {
	let didChange: () -> Void
	let report: (_ message: String) -> Void
}

/// Sections the page refreshes on its tick; `isFullRefresh` is false on the cheap ticks between slow ones.
@MainActor
protocol NetworkRefreshing: AnyObject {
	func refresh(isFullRefresh: Bool) async
}
