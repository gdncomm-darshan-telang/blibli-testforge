import Combine

/// Which Reports view shows, so other screens can open one directly (D-189: ending a batch opens its report).
@MainActor
final class ReportsNavigator: ObservableObject {
	@Published var mode: ReportsMode = .session
	@Published var selectedBatchId: String?

	func showBatch(id: String) {
		selectedBatchId = id
		mode = .batches
	}
}
