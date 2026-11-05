import Combine
import Foundation

enum RunStopTarget: Equatable {
	case batch
	case job(id: String)
}

struct RunActivityProgress: Equatable {
	let title: String
	let detail: String
	let stepText: String?
	let stopTarget: RunStopTarget

	/// Set while a batch holds before its next case; the menu offers Continue.
	let pauseReason: String?
}

enum RunControlAction: Equatable {
	case stop
	case resume
}

enum RunActivityState: Equatable {
	case idle(lastResult: String?)
	case running(RunActivityProgress)
}

struct RunActivityDependencies {
	let store: StateStore
	let service: RunStopping
	let resultsService: ResultsActing
	let notifier: FinishNotifying
	let dockBadge: DockBadging
	let preferences: TestForgePreferences
}

/// Recommendation #10: what runs now for the menu bar, and a notice plus Dock badge when a run ends.
/// Finishes are found by diffing slices; the first read of each slice is only a baseline, so launching never notifies.
@MainActor
final class RunActivityViewModel: ObservableObject {
	@Published private(set) var state: RunActivityState = .idle(lastResult: nil)
	@Published private(set) var stopError: String?

	/// The menu closes on click, so the in-flight Stop/Continue shows on reopening and a failure also posts a notice.
	@Published private(set) var pendingControl: RunControlAction?

	private let dependencies: RunActivityDependencies
	private var runningBatchIds: Set<String>?
	private var endedRunIds: Set<String>?
	private var lastResult: String?
	private var cancellables = Set<AnyCancellable>()
	private var tasks: [Task<Void, Never>] = []

	init(dependencies: RunActivityDependencies) {
		self.dependencies = dependencies
		observeStore()
		observePreferences()
	}

	deinit {
		tasks.forEach { $0.cancel() }
	}

	/// "Stopping…" lasts until the run actually ends, not just until the server accepts the request.
	func stop() {
		guard case .running(let progress) = state,
			pendingControl == nil
		else {
			return
		}
		let service = dependencies.service
		runControl(action: .stop) {
			switch progress.stopTarget {
				case .batch:
					try await service.stopBatch()
				case .job(let id):
					try await service.cancelRun(jobId: id)
			}
		}
	}

	func resume() {
		guard pendingControl == nil else {
			return
		}
		let service = dependencies.service
		runControl(action: .resume) {
			try await service.resumeBatch()
		}
	}

	private func runControl(action: RunControlAction, work: @escaping () async throws -> Void) {
		stopError = nil
		pendingControl = action
		let task = Task { [weak self] in
			do {
				try await work()
				if action == .resume {
					self?.pendingControl = nil
				}
			} catch {
				self?.failControl(action: action, message: error.localizedDescription)
			}
		}
		tasks.append(task)
	}

	private func failControl(action: RunControlAction, message: String) {
		pendingControl = nil
		stopError = message
		let title = action == .stop ? String(localized: "Couldn't stop the run") : String(localized: "Couldn't continue the batch")
		let notice = FinishNotice(title: title, body: message, isAlertOnly: true)
		dependencies.notifier.post(notice: notice)
	}

	func clearBadge() {
		dependencies.dockBadge.show(count: nil)
	}

	private func observeStore() {
		dependencies.store.$slices
			.receive(on: DispatchQueue.main)
			.sink { [weak self] _ in
				self?.readSlices()
			}
			.store(in: &cancellables)
	}

	private func observePreferences() {
		dependencies.preferences.$isFinishNotificationOn
			.removeDuplicates()
			.sink { [weak self] isOn in
				guard isOn else {
					self?.clearBadge()
					return
				}
				self?.dependencies.notifier.prepare()
			}
			.store(in: &cancellables)
	}

	private func readSlices() {
		let narration = dependencies.store.value(of: .narration, as: NarrationState.self)
		let results = dependencies.store.value(of: .results, as: ResultsState.self)
		if let results {
			detectFinishedBatches(runs: results.runs)
		}
		if let narration {
			detectFinishedRuns(runs: narration.runs, batches: results?.runs ?? [])
		}
		state = RunActivityMapper.state(narration: narration, results: results, lastResult: lastResult)
		if case .idle = state {
			pendingControl = nil
			stopError = nil
		}
	}

	private func detectFinishedBatches(runs: [ResultRunSummary]) {
		let runningIds = Set(runs.filter { ResultsFormatting.isRunning(summary: $0) }.map(\.id))
		if let previousIds = runningBatchIds {
			let finishedIds = previousIds.subtracting(runningIds)
			for summary in runs where finishedIds.contains(summary.id) {
				announceBatch(summary: summary)
			}
		}
		runningBatchIds = runningIds
	}

	private func detectFinishedRuns(runs: [NarratedRun], batches: [ResultRunSummary]) {
		let endedIds = Set(runs.filter { !$0.isRunning }.map(\.id))
		if let previousIds = endedRunIds {
			for run in runs where !run.isRunning && !previousIds.contains(run.id) {
				guard !RunActivityMapper.isPartOfBatch(run: run, batches: batches) else {
					continue
				}
				let notice = RunActivityMapper.singleNotice(run: run)
				let isFailing = ResultsFormatting.tone(for: run.verdict) == .failed
				announce(notice: notice, failingCount: isFailing ? 1 : 0)
			}
		}
		endedRunIds = endedIds
	}

	/// The notice names the failing cases, which only the run's detail carries; a failed fetch still notifies with counts.
	private func announceBatch(summary: ResultRunSummary) {
		let failingCount = RunActivityMapper.failingCount(summary: summary)
		let resultsService = dependencies.resultsService
		let task = Task { [weak self] in
			let items = (try? await resultsService.fetchItems(runId: summary.id)) ?? []
			let failingCaseIds = items
				.filter { ResultsFormatting.tone(for: $0.finalVerdict) == .failed }
				.map(\.caseId)
			let notice = RunActivityMapper.batchNotice(summary: summary, failingCaseIds: failingCaseIds)
			self?.announce(notice: notice, failingCount: failingCount)
		}
		tasks.append(task)
	}

	private func announce(notice: FinishNotice, failingCount: Int) {
		lastResult = RunActivityMapper.lastResultText(notice: notice)
		if case .idle = state {
			state = .idle(lastResult: lastResult)
		}
		guard dependencies.preferences.isFinishNotificationOn else {
			return
		}
		dependencies.notifier.post(notice: notice)
		dependencies.dockBadge.show(count: failingCount)
	}
}
