import Combine
import Foundation

/// Where the demo is; each case is one banner the person sees.
enum DemoPhase: Equatable {
	case idle
	case blocked(reason: String)
	case starting
	case running
	case reviewingResults
	case finished
	case failed(message: String)
}

/// Screen changes the demo asks of the main window; the testforge view model does them.
@MainActor
protocol DemoNavigating: AnyObject {
	func showDemoStep(_ step: DemoStep)
}

enum DemoStep {
	case getReady
	case runningTests
	case results
	case reports
}

struct DemoRunDependencies {
	let store: StateStore
	let testCaseService: TestCaseActing
	let runControl: RunStopping
}

/// The free demo (recommendation 12): two recorded Flash Sale tests, no Claude, then Results and Reports.
/// It refuses to start on a phone that isn't ready and says which part of Get ready to fix.
@MainActor
final class DemoRunViewModel: ObservableObject {
	static let caseIds = ["SF-001", "SF-006"]

	@Published private(set) var phase: DemoPhase = .idle
	@Published private(set) var isStopping = false

	weak var navigator: DemoNavigating?

	private let dependencies: DemoRunDependencies
	private var startTask: Task<Void, Never>?
	private var queueSubscription: AnyCancellable?
	private var hasSeenRunActive = false

	init(dependencies: DemoRunDependencies) {
		self.dependencies = dependencies
	}

	deinit {
		startTask?.cancel()
	}

	func start() {
		guard phase != .starting,
			phase != .running
		else {
			return
		}
		if let reason = blockingReason() {
			phase = .blocked(reason: reason)
			navigator?.showDemoStep(reason == notReadyReason() ? .getReady : .runningTests)
			return
		}
		phase = .starting
		navigator?.showDemoStep(.runningTests)
		let service = dependencies.testCaseService
		startTask = Task { [weak self] in
			do {
				try await service.startBatch(caseIds: Self.caseIds)
				self?.didStartRun()
			} catch {
				self?.phase = .failed(message: error.localizedDescription)
			}
		}
	}

	/// From the results banner to the last stop, Reports.
	func continueToReports() {
		guard phase == .reviewingResults else {
			return
		}
		phase = .finished
		navigator?.showDemoStep(.reports)
	}

	/// The banner stays until the server confirms the stop; a refused stop turns it into the failure banner.
	func stop() {
		let wasRunning = phase == .running || phase == .starting
		guard wasRunning else {
			finishWatching()
			phase = .idle
			return
		}
		guard !isStopping else {
			return
		}
		isStopping = true
		startTask?.cancel()
		let runControl = dependencies.runControl
		Task { [weak self] in
			do {
				try await runControl.stopBatch()
				self?.didStop()
			} catch {
				self?.failStop(message: error.localizedDescription)
			}
		}
	}

	private func didStop() {
		isStopping = false
		finishWatching()
		phase = .idle
	}

	private func failStop(message: String) {
		isStopping = false
		finishWatching()
		phase = .failed(message: String(localized: "Couldn't stop the demo's tests: \(message). They may still be running — stop them from the Run queue."))
	}

	private func didStartRun() {
		phase = .running
		hasSeenRunActive = false
		queueSubscription = dependencies.store.$slices
			.receive(on: RunLoop.main)
			.sink { [weak self] _ in
				self?.checkRunProgress()
			}
	}

	/// The queue goes busy once the batch starts and idle when both tests have finished.
	private func checkRunProgress() {
		let isActive = dependencies.store.value(of: .queue, as: QueueState.self)?.hasActiveTask ?? false
		if isActive {
			hasSeenRunActive = true
			return
		}
		guard hasSeenRunActive,
			phase == .running
		else {
			return
		}
		finishWatching()
		phase = .reviewingResults
		navigator?.showDemoStep(.results)
	}

	private func finishWatching() {
		startTask?.cancel()
		queueSubscription = nil
	}

	private func blockingReason() -> String? {
		if let notReady = notReadyReason() {
			return notReady
		}
		let document = dependencies.store.value(of: .testcases, as: TestCaseDocument.self)
		let recorded = Set(document?.cases.filter { $0.recording != nil }.map(\.id) ?? [])
		let missing = Self.caseIds.filter { !recorded.contains($0) }
		guard missing.isEmpty else {
			let list = missing.joined(separator: ", ")
			return String(localized: "The demo replays \(list), which aren't loaded with recorded steps. Load the Flash Sale test document in Tests first.")
		}
		return nil
	}

	private func notReadyReason() -> String? {
		let report = dependencies.store.value(of: .readiness, as: ReadinessReport.self)
		guard report?.isReady != true else {
			return nil
		}
		let failing = report?.checks.first { !$0.isPassing && $0.level == "block" }
		let name = failing?.label ?? String(localized: "a check")
		return String(localized: "Get ready isn't green yet: \(name). Use its Fix button, then start the demo again.")
	}
}
