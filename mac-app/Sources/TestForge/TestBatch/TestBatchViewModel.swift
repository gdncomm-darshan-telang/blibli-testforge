import Combine
import Foundation

enum TestBatchPillState: Equatable {
	case loading
	case needsProofFolder
	case noBatch(proofRoot: String)
	case active(TestBatchSummary, proofRoot: String)
}

/// D-213: what the pill or the start sheet is doing, so the control shows it until the server answers.
enum TestBatchAction: Equatable {
	case chooseFolder
	case start
	case end
	case reopen
	case pause
	case resume(batchId: String)
}

enum TestBatchActionState: Equatable {
	case idle
	case working(TestBatchAction)
	case failed(TestBatchAction, message: String)
}

/// Exactly what the toolbar pill and the start sheet read and call.
@MainActor
protocol TestBatchPresenting: ObservableObject {
	var pillState: TestBatchPillState { get }
	var actionState: TestBatchActionState { get }
	var isStartSheetShown: Bool { get set }
	var isEndConfirmationShown: Bool { get set }
	var draftName: String { get set }
	var canStart: Bool { get }
	var reopenableBatches: [TestBatchSummary] { get }
	var pendingReopen: TestBatchSummary? { get set }
	var pausedBatches: [TestBatchSummary] { get }

	/// D-212: what starting a batch now does to the active one; nil when none is active.
	var startNote: String? { get }

	func chooseProofFolder()
	func requestStart()
	func confirmStart()
	func requestEnd()
	func confirmEnd()
	func revealFolder()
	func requestReopen(batch: TestBatchSummary)
	func confirmReopen()
	func pause()
	func resume(batch: TestBatchSummary)
	func cancelStart()
	func dismissFailure()
}

struct TestBatchDependencies {
	let service: TestBatchActing
	let store: StateStore
	let desktop: DesktopActing
}

/// Proof folder + Test Batch (R4j): the server owns both; this only picks, starts, ends and reveals.
/// Whole-class `@MainActor`: it only orchestrates published state and the folder panel.
@MainActor
final class TestBatchViewModel: ObservableObject, TestBatchPresenting {
	@Published private(set) var pillState: TestBatchPillState = .loading
	@Published private(set) var actionState: TestBatchActionState = .idle
	@Published var isStartSheetShown = false
	@Published var isEndConfirmationShown = false
	@Published var draftName = ""
	@Published private(set) var reopenableBatches: [TestBatchSummary] = []
	@Published var pendingReopen: TestBatchSummary?
	@Published private(set) var pausedBatches: [TestBatchSummary] = []

	/// D-189: ending a batch shows its report in Reports › Batches; without it, the report is revealed in Finder.
	var openBatchReport: ((String) -> Void)?

	private let dependencies: TestBatchDependencies
	private var snapshot: TestBatchSnapshot?
	private var actionTask: Task<Void, Never>?
	private var cancellables = Set<AnyCancellable>()

	init(dependencies: TestBatchDependencies) {
		self.dependencies = dependencies
		observeStore()
	}

	deinit {
		actionTask?.cancel()
	}

	var canStart: Bool {
		!draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isWorking
	}

	func chooseProofFolder() {
		let startingPath = snapshot?.proofRoot ?? snapshot?.suggestedRoot
		let startingURL = startingPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
		let desktop = dependencies.desktop
		let service = dependencies.service
		perform(.chooseFolder) { [weak self] in
			let prompt = String(localized: "Choose proof folder")
			guard let folderURL = await desktop.chooseFolder(prompt: prompt, startingAt: startingURL) else {
				return
			}
			try await service.setProofRoot(path: folderURL.path)
			// The slice update arrives a moment later; a Test Batch is the next step either way.
			self?.draftName = ""
			self?.isStartSheetShown = true
		}
	}

	var startNote: String? {
		guard case .active(let batch, _) = pillState else {
			return nil
		}
		return String(localized: "“\(batch.name)” is paused first; resume it from this menu or Reports › Batches whenever you like.")
	}

	/// With a batch active (D-212), the new one starts after the active one is paused, never ended.
	func requestStart() {
		switch pillState {
			case .loading:
				return
			case .needsProofFolder:
				chooseProofFolder()
				return
			case .noBatch, .active:
				break
		}
		draftName = ""
		dismissFailure()
		isStartSheetShown = true
	}

	func confirmStart() {
		guard canStart else {
			return
		}
		let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
		let isPausingActive = startNote != nil
		let service = dependencies.service
		perform(.start) { [weak self] in
			try await service.start(name: name, isPausingActive: isPausingActive)
			self?.isStartSheetShown = false
		}
	}

	func requestEnd() {
		guard case .active = pillState else {
			return
		}
		isEndConfirmationShown = true
	}

	func confirmEnd() {
		isEndConfirmationShown = false
		guard case .active(let batch, _) = pillState else {
			return
		}
		let service = dependencies.service
		let desktop = dependencies.desktop
		perform(.end) { [weak self] in
			let ended = try await service.end(batchId: batch.id)
			if let openBatchReport = self?.openBatchReport {
				openBatchReport(ended.id)
			} else if let reportPath = ended.reportPath {
				desktop.reveal(url: URL(fileURLWithPath: reportPath))
			}
		}
	}

	func requestReopen(batch: TestBatchSummary) {
		pendingReopen = batch
	}

	/// Proof and new work join the reopened batch's folder again; a batch active now is paused (D-212).
	func confirmReopen() {
		guard let batch = pendingReopen else {
			return
		}
		pendingReopen = nil
		let service = dependencies.service
		perform(.reopen) {
			try await service.reopen(batchId: batch.id)
		}
	}

	/// D-212: sets the active batch aside, so other work can run without ending it.
	func pause() {
		guard case .active(let batch, _) = pillState else {
			return
		}
		let service = dependencies.service
		perform(.pause) {
			try await service.pause(batchId: batch.id)
		}
	}

	/// The batch active at that moment is paused by the server, so switching back and forth never ends either.
	func resume(batch: TestBatchSummary) {
		let service = dependencies.service
		perform(.resume(batchId: batch.id)) { [weak self] in
			try await service.resume(batchId: batch.id)
			self?.isStartSheetShown = false
		}
	}

	func revealFolder() {
		let folderURL: URL
		switch pillState {
			case .active(let batch, let proofRoot):
				folderURL = URL(fileURLWithPath: proofRoot, isDirectory: true).appendingPathComponent(batch.folder, isDirectory: true)
			case .noBatch(let proofRoot):
				folderURL = URL(fileURLWithPath: proofRoot, isDirectory: true)
			case .loading, .needsProofFolder:
				return
		}
		dependencies.desktop.open(url: folderURL)
	}

	/// A failure in the start sheet shows there, so closing the sheet drops it instead of raising the pill's alert.
	func cancelStart() {
		isStartSheetShown = false
		if !isWorking {
			actionState = .idle
		}
	}

	func dismissFailure() {
		if case .failed = actionState {
			actionState = .idle
		}
	}

	/// One request at a time: a second click while one is in flight is ignored rather than cancelling the first.
	private func perform(_ action: TestBatchAction, operation: @escaping @MainActor () async throws -> Void) {
		guard !isWorking else {
			return
		}
		actionState = .working(action)
		actionTask = Task { [weak self] in
			do {
				try await operation()
				self?.actionState = .idle
			} catch {
				self?.actionState = .failed(action, message: error.localizedDescription)
			}
		}
	}

	private func observeStore() {
		let store = dependencies.store
		store.$slices
			.receive(on: RunLoop.main)
			.sink { [weak self] _ in
				let snapshot = store.value(of: .testBatch, as: TestBatchSnapshot.self)
				self?.apply(snapshot: snapshot)
			}
			.store(in: &cancellables)
	}

	private func apply(snapshot: TestBatchSnapshot?) {
		self.snapshot = snapshot
		reopenableBatches = Array((snapshot?.endedBatches ?? []).prefix(TestForgeConstants.TestBatch.reopenMenuLimit))
		pausedBatches = snapshot?.pausedBatches ?? []
		guard let snapshot else {
			pillState = .loading
			return
		}
		guard let proofRoot = snapshot.proofRoot else {
			pillState = .needsProofFolder
			return
		}
		if let active = snapshot.active {
			pillState = .active(active, proofRoot: proofRoot)
		} else {
			pillState = .noBatch(proofRoot: proofRoot)
		}
	}
}
