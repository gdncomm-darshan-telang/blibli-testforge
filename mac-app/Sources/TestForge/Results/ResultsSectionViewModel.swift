import Combine
import Foundation
import UniformTypeIdentifiers

struct ResultRunRowModel: Equatable, Identifiable {
	let id: String
	let title: String
	let subtitle: String
	let countsText: String
	let reviewText: String
	let isValidated: Bool
	let isRunning: Bool
}

struct ResultFactModel: Equatable, Identifiable {
	let id: String
	let label: String
	let value: String
}

struct ResultTileModel: Equatable, Identifiable {
	let id: String
	let title: String
	let value: String
	let tone: VerdictTone
}

struct ResultRunHeaderModel: Equatable {
	let title: String
	let facts: [ResultFactModel]
	let warning: String?
	let tiles: [ResultTileModel]
	let reviewText: String
	let isValidated: Bool
	let canRerunFailed: Bool
}

struct ResultCaseRowModel: Equatable, Identifiable {
	let id: Int
	let caseId: String
	let scenario: String
	let ranAsText: String
	let verdictText: String
	let verdictTone: VerdictTone
	let reviewText: String
	let isReviewed: Bool
	let proofLocationURL: URL?
}

struct ResultRunDetailModel: Equatable {
	let header: ResultRunHeaderModel
	let cases: [ResultCaseRowModel]
}

struct ResultNoteModel: Equatable, Identifiable {
	let id: String
	let symbolName: String
	let title: String
	let text: String
}

struct ResultCaseDetailModel: Equatable {
	let index: Int
	let caseId: String
	let scenario: String
	let verdictText: String
	let verdictTone: VerdictTone
	let historyText: String
	let reviewText: String
	let notes: [ResultNoteModel]
	let mocks: [String]
	let screenshotURLs: [URL]
	let videoURLs: [URL]
	let proofLocationURL: URL?
	let summary: String?
	let steps: [String]

	/// Screenshots first, then videos — the order the inspector lists them.
	func proofViewerRequest(selecting url: URL) -> ProofViewerRequest {
		ProofViewerRequest(title: "\(caseId) proof", urls: screenshotURLs + videoURLs, selectedURL: url)
	}
}

struct ResultOverrideDraft: Equatable, Identifiable {
	let id: Int
	let caseId: String
}

enum ResultRunListState: Equatable {
	case empty
	case loaded([ResultRunRowModel])
}

enum ResultRunDetailState: Equatable {
	case noSelection
	case loading
	case loaded(ResultRunDetailModel)
	case failed(message: String)
}

struct ResultsSectionDependencies {
	let store: StateStore
	let service: ResultsActing
	let bundles: BundleActing
	let desktop: DesktopActing
}

/// Board C9: kept runs, one run's cases, and the selected case's proof with its review.
/// Whole-class `@MainActor`: every method maps the `results` slice to published state; requests run in the service.
@MainActor
final class ResultsSectionViewModel: ObservableObject {
	@Published private(set) var listState: ResultRunListState = .empty
	@Published private(set) var detailState: ResultRunDetailState = .noSelection
	@Published private(set) var caseDetail: ResultCaseDetailModel?
	@Published private(set) var actionMessage: String?
	@Published private(set) var runningAction: ResultAction?
	@Published private(set) var lastOutcome: ResultActionOutcome?
	@Published var pendingOverride: ResultOverrideDraft?
	@Published var isRerunConfirmationPresented = false
	let bundleImportViewModel: BundleImportViewModel
	@Published var selectedRunId: String? {
		didSet {
			selectedRunDidChange(from: oldValue)
		}
	}

	@Published var selectedCaseIndex: Int? {
		didSet {
			if oldValue != selectedCaseIndex,
				runningAction == nil {
				lastOutcome = nil
			}
			refreshCaseDetail()
		}
	}

	private let store: StateStore
	private let service: ResultsActing
	private let desktop: DesktopActing
	private let bundles: BundleActing
	private var summaries: [ResultRunSummary] = []
	private var items: [ResultItem] = []
	private var loadedUpdatedAt: String?
	private var cancellables = Set<AnyCancellable>()
	private var detailTask: Task<Void, Never>?
	private var actionTask: Task<Void, Never>?

	private var selectedSummary: ResultRunSummary? {
		summaries.first { $0.id == selectedRunId }
	}

	var feedback: ResultActionFeedback {
		ResultActionFeedback(runningAction: runningAction, outcome: lastOutcome)
	}

	var overrideSheet: OverrideVerdictSheetModel? {
		guard let pendingOverride else {
			return nil
		}
		return OverrideVerdictSheetModel(
			caseId: pendingOverride.caseId,
			isSaving: runningAction == .saveOverride,
			failure: feedback.overrideFailure
		)
	}

	init(dependencies: ResultsSectionDependencies) {
		store = dependencies.store
		service = dependencies.service
		desktop = dependencies.desktop
		bundles = dependencies.bundles
		bundleImportViewModel = BundleImportViewModel(service: dependencies.bundles, desktop: dependencies.desktop)
		observeStore()
	}

	deinit {
		detailTask?.cancel()
		actionTask?.cancel()
	}

	func acceptSelectedCase() {
		review(decision: .accept, action: .accept)
	}

	func markSelectedCaseForRerun() {
		review(decision: .needsRerun, action: .needsRerun)
	}

	func requestOverride() {
		guard let caseDetail else {
			return
		}
		lastOutcome = nil
		pendingOverride = ResultOverrideDraft(id: caseDetail.index, caseId: caseDetail.caseId)
	}

	/// The sheet stays open while saving, so a failure shows inside it; it closes on success.
	func saveOverride(verdict: String, reason: String) {
		let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
		review(decision: .override(verdict: verdict, reason: trimmedReason), action: .saveOverride)
	}

	func cancelOverride() {
		guard runningAction != .saveOverride else {
			return
		}
		pendingOverride = nil
	}

	/// Recorded cases replay without Claude; the rest run through Claude, so the view confirms first.
	func confirmRerunFailed() {
		isRerunConfirmationPresented = false
		guard let runId = selectedRunId else {
			return
		}
		perform(.rerunFailed) { service, _ in
			try await service.rerunFailed(runId: runId)
			return String(localized: "Re-run started — it shows in the run list.")
		}
	}

	func exportReport() {
		guard let summary = selectedSummary else {
			return
		}
		let fileName = ResultsFormatting.reportFileName(summary: summary)
		perform(.exportReport) { service, desktop in
			let markdown = try await service.reportMarkdown(runId: summary.id)
			let savedURL = try await desktop.saveText(text: markdown, suggestedFileName: fileName)
			return savedURL.map { String(localized: "Report saved to \($0.path)") }
		}
	}

	/// D-162: the run as one file the next person imports and replays without Claude.
	func exportBundle() {
		guard let summary = selectedSummary else {
			return
		}
		let fileName = ResultsFormatting.bundleFileName(summary: summary)
		let bundles = bundles
		perform(.exportBundle) { _, desktop in
			let data = try await bundles.exportBundle(runId: summary.id)
			let savedURL = try await desktop.saveData(data, suggestedFileName: fileName, contentType: .json)
			return savedURL.map { String(localized: "Bundle saved to \($0.path)") }
		}
	}

	func copyReport() {
		guard let runId = selectedRunId else {
			return
		}
		perform(.copyReport) { service, desktop in
			let markdown = try await service.reportMarkdown(runId: runId)
			desktop.copy(text: markdown)
			return String(localized: "Copied the report as Markdown.")
		}
	}

	/// A case's own folder opens in Finder; a proof file in a shared folder is shown selected there.
	func showProofInFinder(url: URL) {
		if url.hasDirectoryPath {
			desktop.open(url: url)
		} else {
			desktop.reveal(url: url)
		}
	}

	func dismissMessage() {
		actionMessage = nil
	}

	private func review(decision: ReviewDecision, action: ResultAction) {
		guard let runId = selectedRunId,
			let caseIndex = selectedCaseIndex
		else {
			return
		}
		let confirmation = action == .needsRerun
			? String(localized: "Marked for re-run.")
			: String(localized: "Review saved.")
		perform(action) { service, _ in
			try await service.review(runId: runId, caseIndex: caseIndex, decision: decision)
			return confirmation
		}
	}

	/// One request at a time, so a second click can't cancel the first; `request` returns the confirmation, nil when cancelled.
	private func perform(_ action: ResultAction, request: @escaping (ResultsActing, DesktopActing) async throws -> String?) {
		guard runningAction == nil else {
			return
		}
		actionMessage = nil
		lastOutcome = nil
		runningAction = action
		let service = service
		let desktop = desktop
		actionTask = Task { [weak self] in
			do {
				let confirmation = try await request(service, desktop)
				self?.finish(action, confirmation: confirmation)
			} catch {
				self?.fail(action, error: error)
			}
		}
	}

	private func finish(_ action: ResultAction, confirmation: String?) {
		runningAction = nil
		if action == .saveOverride {
			pendingOverride = nil
		}
		lastOutcome = confirmation.map { ResultActionOutcome(action: action, message: $0, isSuccess: true) }
	}

	/// An override failure shows inside its sheet; every other failure keeps the existing alert.
	private func fail(_ action: ResultAction, error: Error) {
		runningAction = nil
		guard action == .saveOverride else {
			actionMessage = error.localizedDescription
			return
		}
		lastOutcome = ResultActionOutcome(action: action, message: error.localizedDescription, isSuccess: false)
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
		let rows = ResultsSectionMapper.runRows(from: summaries)
		listState = rows.isEmpty ? .empty : .loaded(rows)
		guard let summary = selectedSummary else {
			selectedRunId = summaries.first?.id
			return
		}
		if summary.updatedAt != loadedUpdatedAt {
			loadDetail(for: summary, showsProgress: false)
		}
	}

	private func selectedRunDidChange(from previousRunId: String?) {
		guard previousRunId != selectedRunId else {
			return
		}
		items = []
		loadedUpdatedAt = nil
		lastOutcome = nil
		selectedCaseIndex = nil
		guard let summary = selectedSummary else {
			detailTask?.cancel()
			detailState = .noSelection
			return
		}
		loadDetail(for: summary, showsProgress: true)
	}

	private func loadDetail(for summary: ResultRunSummary, showsProgress: Bool) {
		detailTask?.cancel()
		if showsProgress {
			detailState = .loading
		}
		let service = service
		detailTask = Task { [weak self] in
			do {
				let items = try await service.fetchItems(runId: summary.id)
				self?.applyDetail(items: items, summary: summary)
			} catch {
				guard !Task.isCancelled else {
					return
				}
				self?.detailState = .failed(message: error.localizedDescription)
			}
		}
	}

	private func applyDetail(items newItems: [ResultItem], summary: ResultRunSummary) {
		guard summary.id == selectedRunId else {
			return
		}
		items = newItems
		loadedUpdatedAt = summary.updatedAt
		let header = ResultsSectionMapper.header(for: summary, items: newItems)
		let cases = ResultsSectionMapper.caseRows(from: newItems)
		detailState = .loaded(ResultRunDetailModel(header: header, cases: cases))
		if let selectedCaseIndex,
			newItems[safe: selectedCaseIndex] == nil {
			self.selectedCaseIndex = nil
		}
		refreshCaseDetail()
	}

	private func refreshCaseDetail() {
		guard let selectedCaseIndex,
			let item = items[safe: selectedCaseIndex]
		else {
			caseDetail = nil
			return
		}
		caseDetail = ResultsSectionMapper.caseDetail(for: item, index: selectedCaseIndex)
	}
}

extension TestForgeViewModel {
	static func makeResultsViewModel(services: TestForgeServices) -> ResultsSectionViewModel {
		let dependencies = ResultsSectionDependencies(
			store: services.store,
			service: services.resultsService,
			bundles: services.bundles,
			desktop: services.desktop
		)
		return ResultsSectionViewModel(dependencies: dependencies)
	}
}
