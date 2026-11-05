import Combine
import Foundation

struct BatchReportRowModel: Equatable, Identifiable {
	let id: String
	let name: String
	let dateText: String
	let progressText: String
	let status: TestBatchStatus
	let hasFailures: Bool
}

enum BatchReportState: Equatable {
	case noSelection
	case loading
	case loaded([MarkdownBlockItem])
	case failed(message: String)
}

struct BatchReportDetailModel: Equatable {
	let id: String
	let name: String
	let statusText: String
	let progressText: String
	let folderText: String
	let status: TestBatchStatus
	let comparisonText: String?
	let hasRegressions: Bool
	let canReplay: Bool
}

enum BatchReportAction: Equatable {
	case refresh
	case pause
	case resume
	case end
	case reopen
	case replay
	case remove
}

struct BatchReportsDependencies {
	let store: StateStore
	let service: TestBatchActing
	let desktop: DesktopActing
	let navigator: ReportsNavigator
}

/// Reports › Batches (D-189): every Test Batch with its progress and report; pause, resume, reopen, end, remove or show its folder.
/// Whole-class `@MainActor`: it maps the `testBatch` slice to rows and forwards actions.
@MainActor
final class BatchReportsViewModel: ObservableObject {
	@Published private(set) var rows: [BatchReportRowModel] = []
	@Published private(set) var detail: BatchReportDetailModel?
	@Published private(set) var reportState: BatchReportState = .noSelection
	@Published var actionMessage: String?
	@Published var pendingRemoval: BatchReportDetailModel?
	@Published var pendingReplay: BatchReportDetailModel?
	@Published var replayNotice: String?
	@Published private(set) var runningAction: BatchReportAction?

	private let dependencies: BatchReportsDependencies
	private var snapshot: TestBatchSnapshot?
	private var reportTask: Task<Void, Never>?
	private var actionTask: Task<Void, Never>?
	private var loadedReportKey: String?
	private var cancellables = Set<AnyCancellable>()

	init(dependencies: BatchReportsDependencies) {
		self.dependencies = dependencies
		observe()
	}

	deinit {
		reportTask?.cancel()
		actionTask?.cancel()
	}

	var selectedBatchId: String? {
		get { dependencies.navigator.selectedBatchId }
		set { dependencies.navigator.selectedBatchId = newValue }
	}

	var isBusy: Bool {
		runningAction != nil
	}

	func isRunning(_ action: BatchReportAction) -> Bool {
		runningAction == action
	}

	/// The spinner stays on Refresh until the rewritten report has loaded, even while the old one stays on screen.
	func reloadReport() {
		guard runningAction == nil else {
			return
		}
		runningAction = .refresh
		forceReloadReport()
	}

	func reopenSelected() {
		guard let id = detail?.id else {
			return
		}
		let service = dependencies.service
		perform(.reopen) { try await service.reopen(batchId: id) }
	}

	func pauseSelected() {
		guard let id = detail?.id else {
			return
		}
		let service = dependencies.service
		perform(.pause) { try await service.pause(batchId: id) }
	}

	func resumeSelected() {
		guard let id = detail?.id else {
			return
		}
		let service = dependencies.service
		perform(.resume) { try await service.resume(batchId: id) }
	}

	func endSelected() {
		guard let id = detail?.id else {
			return
		}
		let service = dependencies.service
		perform(.end) { [weak self] in
			_ = try await service.end(batchId: id)
			self?.forceReloadReport()
		}
	}

	func requestReplaySelected() {
		pendingReplay = detail
	}

	/// Starts the regression replay; on success the new batch is selected so its comparison fills in live.
	func confirmReplay() {
		guard let id = pendingReplay?.id else {
			return
		}
		pendingReplay = nil
		let service = dependencies.service
		perform(.replay) { [weak self] in
			let started = try await service.replay(batchId: id)
			self?.selectedBatchId = started.batchId
			self?.replayNotice = BatchReportsMapper.replayNotice(for: started)
		}
	}

	func requestRemoveSelected() {
		pendingRemoval = detail
	}

	func confirmRemove() {
		guard let id = pendingRemoval?.id else {
			return
		}
		pendingRemoval = nil
		let service = dependencies.service
		perform(.remove) { [weak self] in
			try await service.remove(batchId: id)
			self?.selectedBatchId = nil
		}
	}

	func revealSelected() {
		guard let url = folderURL() else {
			return
		}
		dependencies.desktop.open(url: url)
	}

	private func folderURL() -> URL? {
		guard let proofRoot = snapshot?.proofRoot,
			let batch = selectedBatch
		else {
			return nil
		}
		return URL(fileURLWithPath: proofRoot, isDirectory: true).appendingPathComponent(batch.folder, isDirectory: true)
	}

	private var selectedBatch: TestBatchSummary? {
		snapshot?.batches.first { $0.id == selectedBatchId }
	}

	/// One request at a time, so a second click can't cancel the first; failures keep the existing alert.
	private func perform(_ action: BatchReportAction, operation: @escaping @MainActor () async throws -> Void) {
		guard runningAction == nil else {
			return
		}
		runningAction = action
		actionTask = Task { [weak self] in
			do {
				try await operation()
			} catch {
				self?.actionMessage = error.localizedDescription
			}
			self?.runningAction = nil
		}
	}

	private func forceReloadReport() {
		loadedReportKey = nil
		refreshDetail()
	}

	private func finishRefreshIfNeeded() {
		if runningAction == .refresh {
			runningAction = nil
		}
	}

	private func observe() {
		let store = dependencies.store
		store.$slices
			.receive(on: RunLoop.main)
			.sink { [weak self] _ in
				self?.apply(snapshot: store.value(of: .testBatch, as: TestBatchSnapshot.self))
			}
			.store(in: &cancellables)
		dependencies.navigator.$selectedBatchId
			.removeDuplicates()
			.receive(on: RunLoop.main)
			.sink { [weak self] _ in
				self?.objectWillChange.send()
				self?.refreshDetail()
			}
			.store(in: &cancellables)
	}

	private func apply(snapshot: TestBatchSnapshot?) {
		self.snapshot = snapshot
		rows = (snapshot?.batches ?? []).map { BatchReportsMapper.row(for: $0) }
		if selectedBatchId == nil {
			selectedBatchId = rows.first?.id
		}
		refreshDetail()
	}

	/// The report is fetched again only when the batch's work changed, so a live batch's report keeps up.
	private func refreshDetail() {
		guard let batch = selectedBatch else {
			detail = nil
			reportState = .noSelection
			loadedReportKey = nil
			finishRefreshIfNeeded()
			return
		}
		detail = BatchReportsMapper.detail(for: batch)
		let key = "\(batch.id)|\(batch.itemCount)|\(batch.status)|\(batch.progress.running)"
		guard key != loadedReportKey else {
			return
		}
		loadedReportKey = key
		if case .loaded = reportState {
			// Keep showing the previous report while the new one loads.
		} else {
			reportState = .loading
		}
		let service = dependencies.service
		reportTask?.cancel()
		reportTask = Task { [weak self] in
			do {
				let text = try await service.report(batchId: batch.id)
				let blocks = await Task.detached(priority: .userInitiated) { MarkdownParser.parse(text) }.value
				guard !Task.isCancelled else {
					return
				}
				self?.reportState = .loaded(blocks)
			} catch {
				guard !Task.isCancelled else {
					return
				}
				self?.reportState = .failed(message: error.localizedDescription)
			}
			self?.finishRefreshIfNeeded()
		}
	}
}
