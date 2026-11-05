import Combine
import Foundation

struct ScanCurrentModel: Equatable {
	let countsText: String
	let identifiers: [String]
	let isTruncated: Bool
	let changedAt: Date?
}

struct ScanScreenRowModel: Equatable, Identifiable {
	let id: String
	let name: String
	let detail: String
	let hasWarning: Bool
}

struct ScanLiveModel: Equatable {
	let title: String
	let subtitle: String
	let current: ScanCurrentModel?
	let screens: [ScanScreenRowModel]
	let warning: String?
	let isStopping: Bool
}

struct ScanSummaryModel: Equatable {
	let title: String
	let detail: String
	let outURL: URL?
	let failure: String?
	let screens: [ScanScreenRowModel]
}

enum ScanSectionState: Equatable {
	case idle(lastScan: ScanSummaryModel?)
	case active(ScanLiveModel)
}

enum ScanAction: Equatable {
	case start
	case mark
	case skip
	case stop
	case showSimulator
}

struct ScanMarkBarModel: Equatable {
	let canMark: Bool
	let isMarking: Bool
	let isSkipping: Bool
	let confirmation: String?
}

/// Scan mode (D-086): the person drives the app, this screen shows what the harness sees and records named screens.
/// Whole-class `@MainActor`: every method only maps the `scan` slice to published state; requests run in the service.
@MainActor
final class ScanSectionViewModel: ObservableObject {
	@Published private(set) var state: ScanSectionState = .idle(lastScan: nil)
	@Published private(set) var actionMessage: String?
	@Published private(set) var runningAction: ScanAction?
	@Published private(set) var markConfirmation: String?
	@Published var screenName = ""

	private let store: StateStore
	private let service: ScanActing
	private let desktop: DesktopActing
	private var cancellables = Set<AnyCancellable>()
	private var actionTask: Task<Void, Never>?

	var canMark: Bool {
		guard case .active(let live) = state else {
			return false
		}
		return !live.isStopping && runningAction == nil && !screenName.trimmingCharacters(in: .whitespaces).isEmpty
	}

	var markBar: ScanMarkBarModel {
		ScanMarkBarModel(
			canMark: canMark,
			isMarking: runningAction == .mark,
			isSkipping: runningAction == .skip,
			confirmation: markConfirmation
		)
	}

	var isActive: Bool {
		guard case .active = state else {
			return false
		}
		return true
	}

	func isRunning(_ action: ScanAction) -> Bool {
		runningAction == action
	}

	init(store: StateStore, service: ScanActing, desktop: DesktopActing) {
		self.store = store
		self.service = service
		self.desktop = desktop
		observeStore()
	}

	deinit {
		actionTask?.cancel()
	}

	/// The server accepts the start before the slice turns active, so "Starting…" holds until it does (or a timeout).
	func startScan() {
		perform(.start) { [weak self] service in
			try await service.start()
			await self?.waitUntilActive()
			return nil
		}
	}

	/// The name is kept so a second mark records another variant (e.g. after scrolling), the supported way to cover a long screen.
	func markScreen() {
		let name = screenName.trimmingCharacters(in: .whitespaces)
		guard canMark else {
			return
		}
		perform(.mark) { service in
			try await service.mark(screenName: name)
			return String(localized: "Marked “\(name)”")
		}
	}

	func skipScreen() {
		perform(.skip) { service in
			try await service.skip()
			return String(localized: "Skipped this screen")
		}
	}

	func stopScan() {
		perform(.stop) { service in
			try await service.stop()
			return nil
		}
	}

	func showSimulator() {
		perform(.showSimulator) { service in
			try await service.showSimulator()
			return nil
		}
	}

	func revealLastScan() {
		guard case .idle(let lastScan) = state,
			let outURL = lastScan?.outURL
		else {
			return
		}
		desktop.reveal(url: outURL)
	}

	func dismissMessage() {
		actionMessage = nil
	}

	/// One request at a time, so a second click can't cancel the first; `request` returns the confirmation to show, if any.
	private func perform(_ action: ScanAction, request: @escaping (ScanActing) async throws -> String?) {
		guard runningAction == nil else {
			return
		}
		actionMessage = nil
		markConfirmation = nil
		runningAction = action
		let service = service
		actionTask = Task { [weak self] in
			do {
				let confirmation = try await request(service)
				self?.markConfirmation = confirmation
			} catch {
				self?.actionMessage = error.localizedDescription
			}
			self?.runningAction = nil
		}
	}

	private func waitUntilActive() async {
		for _ in 0..<TestForgeConstants.FeedbackReview.settlePollAttempts {
			guard !isActive,
				!Task.isCancelled
			else {
				return
			}
			try? await Task.sleep(nanoseconds: TestForgeConstants.FeedbackReview.settlePollNanoseconds)
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

	private func readSlice() {
		guard let scan = store.value(of: .scan, as: ScanState.self) else {
			state = .idle(lastScan: nil)
			return
		}
		if scan.isActive {
			let live = ScanSectionMapper.live(from: scan)
			state = .active(live)
		} else {
			let summary = ScanSectionMapper.summary(from: scan)
			state = .idle(lastScan: summary)
		}
	}
}
