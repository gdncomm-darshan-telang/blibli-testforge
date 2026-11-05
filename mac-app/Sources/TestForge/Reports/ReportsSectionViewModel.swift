import Combine
import Foundation

struct BranchRowModel: Equatable, Identifiable {
	let id: String
	let detail: String
	let runCountText: String
	let tone: VerdictTone
}

struct ReportRunOption: Equatable, Identifiable {
	let id: String
	let title: String
}

struct ComparisonChipModel: Equatable, Identifiable {
	let id: String
	let title: String
	let tone: VerdictTone
}

struct ComparisonRowModel: Equatable, Identifiable {
	let id: String
	let scenario: String
	let baseText: String
	let headText: String
	let changeText: String
	let changeTone: VerdictTone
}

struct RunComparisonModel: Equatable {
	let title: String
	let chips: [ComparisonChipModel]
	let rows: [ComparisonRowModel]
}

struct ReportPreviewModel: Equatable {
	let title: String
	let facts: [ResultFactModel]
}

enum ReportsListState: Equatable {
	case empty
	case loaded([BranchRowModel])
}

enum ReportAction: Equatable {
	case exportReport
	case copyReport
	case publish
}

struct ReportPreviewFeedback: Equatable {
	let noticeText: String?
	let runningAction: ReportAction?

	var isBusy: Bool {
		runningAction != nil
	}

	func isRunning(_ action: ReportAction) -> Bool {
		runningAction == action
	}
}

enum RunComparisonState: Equatable {
	case idle
	case loading
	case loaded(RunComparisonModel)
	case failed(message: String)
}

/// Board C10: history by branch, one run compared with another, and the report made from it.
/// Whole-class `@MainActor`: every method maps the `results` slice to published state; requests run in the service.
@MainActor
final class ReportsSectionViewModel: ObservableObject {
	@Published private(set) var listState: ReportsListState = .empty
	@Published private(set) var runOptions: [ReportRunOption] = []
	@Published private(set) var baseOptions: [ReportRunOption] = []
	@Published private(set) var comparisonState: RunComparisonState = .idle
	@Published private(set) var preview: ReportPreviewModel?
	@Published private(set) var noticeText: String?
	@Published private(set) var actionMessage: String?
	@Published private(set) var runningAction: ReportAction?
	@Published var isPublishConfirmationPresented = false
	@Published var selectedBranch: String? {
		didSet {
			selectedBranchDidChange(from: oldValue)
		}
	}

	@Published var selectedRunId: String? {
		didSet {
			selectionDidChange(isChanged: oldValue != selectedRunId)
		}
	}

	/// Nil lets the server pick: the newest earlier develop run that shares a case, else any earlier one.
	@Published var selectedBaseRunId: String? {
		didSet {
			selectionDidChange(isChanged: oldValue != selectedBaseRunId)
		}
	}

	private let store: StateStore
	private let service: ResultsActing
	private let desktop: DesktopActing
	private var summaries: [ResultRunSummary] = []
	private var comparison: RunComparison?
	private var comparedKey: String?
	private var cancellables = Set<AnyCancellable>()
	private var comparisonTask: Task<Void, Never>?
	private var actionTask: Task<Void, Never>?

	private var selectedSummary: ResultRunSummary? {
		summaries.first { $0.id == selectedRunId }
	}

	var previewFeedback: ReportPreviewFeedback {
		ReportPreviewFeedback(noticeText: noticeText, runningAction: runningAction)
	}

	init(store: StateStore, service: ResultsActing, desktop: DesktopActing) {
		self.store = store
		self.service = service
		self.desktop = desktop
		observeStore()
	}

	deinit {
		comparisonTask?.cancel()
		actionTask?.cancel()
	}

	func exportReport() {
		guard let summary = selectedSummary else {
			return
		}
		let fileName = ResultsFormatting.reportFileName(summary: summary)
		perform(.exportReport) { [weak self] service, desktop in
			let markdown = try await service.reportMarkdown(runId: summary.id)
			let savedURL = try await desktop.saveText(text: markdown, suggestedFileName: fileName)
			if let savedURL {
				self?.noticeText = String(localized: "Saved to \(savedURL.path)")
			}
		}
	}

	func copyReport() {
		guard let runId = selectedRunId else {
			return
		}
		perform(.copyReport) { [weak self] service, desktop in
			let markdown = try await service.reportMarkdown(runId: runId)
			desktop.copy(text: markdown)
			self?.noticeText = String(localized: "Report copied as Markdown.")
		}
	}

	/// Publishing writes to Confluence through Claude, so the view confirms first; it only ever creates a page under the personal page.
	func confirmPublish() {
		isPublishConfirmationPresented = false
		guard let runId = selectedRunId else {
			return
		}
		perform(.publish) { [weak self] service, _ in
			try await service.publish(runId: runId)
			self?.noticeText = String(localized: "Publishing is queued. Claude asks before it writes; follow it in the console.")
		}
	}

	func dismissMessage() {
		actionMessage = nil
	}

	/// One request at a time, so a second click can't cancel the first.
	private func perform(_ action: ReportAction, request: @escaping (ResultsActing, DesktopActing) async throws -> Void) {
		guard runningAction == nil else {
			return
		}
		actionMessage = nil
		noticeText = nil
		runningAction = action
		let service = service
		let desktop = desktop
		actionTask = Task { [weak self] in
			do {
				try await request(service, desktop)
			} catch {
				self?.actionMessage = error.localizedDescription
			}
			self?.runningAction = nil
		}
	}

	private func observeStore() {
		store.$slices
			.receive(on: DispatchQueue.main)
			.sink { [weak self] _ in
				self?.readSlice()
			}
			.store(in: &cancellables)
	}

	/// A slice still pending after a reconnect reads as nil; keeping the old state keeps the selection.
	private func readSlice() {
		guard let results = store.value(of: .results, as: ResultsState.self) else {
			return
		}
		summaries = results.runs
		let branches = results.branches
		let rows = ReportsSectionMapper.branchRows(from: branches)
		listState = rows.isEmpty ? .empty : .loaded(rows)
		guard let selectedBranch,
			branches.contains(where: { $0.branch == selectedBranch })
		else {
			self.selectedBranch = branches.first?.branch
			return
		}
		refreshOptions()
	}

	private func selectedBranchDidChange(from previousBranch: String?) {
		guard previousBranch != selectedBranch else {
			return
		}
		refreshOptions()
		selectedRunId = runOptions.first?.id
	}

	private func refreshOptions() {
		let branch = selectedBranch
		runOptions = ReportsSectionMapper.runOptions(from: summaries.filter { ReportsSectionMapper.branchName(of: $0) == branch })
		if let selectedRunId,
			!runOptions.contains(where: { $0.id == selectedRunId }) {
			self.selectedRunId = runOptions.first?.id
		}
		baseOptions = ReportsSectionMapper.baseOptions(from: summaries.filter { $0.id != selectedRunId })
		if let selectedBaseRunId,
			!baseOptions.contains(where: { $0.id == selectedBaseRunId }) {
			self.selectedBaseRunId = nil
		}
		loadComparisonIfNeeded()
	}

	private func selectionDidChange(isChanged: Bool) {
		guard isChanged else {
			return
		}
		baseOptions = ReportsSectionMapper.baseOptions(from: summaries.filter { $0.id != selectedRunId })
		noticeText = nil
		loadComparisonIfNeeded()
	}

	/// Compares again only when the run, the chosen base or either run's contents changed.
	private func loadComparisonIfNeeded() {
		guard let summary = selectedSummary else {
			comparisonTask?.cancel()
			comparison = nil
			comparedKey = nil
			comparisonState = .idle
			preview = nil
			return
		}
		let baseStamp = summaries.first { $0.id == selectedBaseRunId }?.updatedAt ?? ""
		let key = [summary.id, summary.updatedAt, selectedBaseRunId ?? "", baseStamp].joined(separator: "|")
		guard key != comparedKey else {
			return
		}
		comparedKey = key
		preview = ReportsSectionMapper.preview(for: summary, comparison: nil)
		comparisonState = .loading
		comparisonTask?.cancel()
		let service = service
		let baseRunId = selectedBaseRunId
		comparisonTask = Task { [weak self] in
			do {
				let comparison = try await service.compare(runId: summary.id, baseRunId: baseRunId)
				self?.applyComparison(comparison: comparison, summary: summary)
			} catch {
				guard !Task.isCancelled else {
					return
				}
				self?.comparedKey = nil
				self?.comparisonState = .failed(message: error.localizedDescription)
			}
		}
	}

	private func applyComparison(comparison newComparison: RunComparison, summary: ResultRunSummary) {
		guard summary.id == selectedRunId else {
			return
		}
		comparison = newComparison
		let model = ReportsSectionMapper.comparison(from: newComparison)
		comparisonState = .loaded(model)
		preview = ReportsSectionMapper.preview(for: summary, comparison: newComparison)
	}
}
