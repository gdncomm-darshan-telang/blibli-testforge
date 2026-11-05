import Combine
import Foundation

enum NetworkBreakpointAction: Hashable {
	case add
	case hold
	case remove(id: String)
	case release
	case continueAll
	case bubble(isHidden: Bool)
}

struct NetworkBreakpointFailure: Equatable {
	let action: NetworkBreakpointAction
	let message: String
}

@MainActor
protocol NetworkBreakpointsPresenting: ObservableObject {
	var state: NetworkSectionState<BreakpointsDisplayModel> { get }
	var endpointText: String { get set }
	var stage: NetworkBreakpointStage { get set }
	var isOneShot: Bool { get set }
	var selectedHeldId: String? { get set }
	var selectedHeld: HeldCallModel? { get }
	var editedStatusText: String { get set }
	var editedBody: String { get set }
	var failure: NetworkFailureKind { get set }
	var isWorking: Bool { get }
	var runningAction: NetworkBreakpointAction? { get }
	var actionFailure: NetworkBreakpointFailure? { get }
	var canAdd: Bool { get }

	func add()
	func remove(id: String)
	func continueSelected()
	func failSelected()
	func continueAll()
	func setBubble(isHidden: Bool)
}

/// Breakpoints tab (D-130): hold matching calls in the running app, edit what is held, let it go on or fail it.
/// Live only: everything here is a phase-D NetworkLens verb, so an older app build answers with the reason instead.
@MainActor
final class NetworkBreakpointsSectionViewModel: NetworkBreakpointsPresenting {
	@Published private(set) var state: NetworkSectionState<BreakpointsDisplayModel> = .notLoaded
	@Published private(set) var runningAction: NetworkBreakpointAction?
	@Published private(set) var actionFailure: NetworkBreakpointFailure?
	@Published var endpointText = ""
	@Published var stage: NetworkBreakpointStage = .response
	@Published var isOneShot = false
	@Published var editedStatusText = ""
	@Published var editedBody = ""
	@Published var failure: NetworkFailureKind = .timedOut
	@Published var selectedHeldId: String? {
		didSet {
			fillEditor()
		}
	}

	private let service: NetworkBreakpointControlling
	private let events: NetworkSectionEvents
	private let clock: () -> Date
	private var actionTask: Task<Void, Never>?

	var selectedHeld: HeldCallModel? {
		state.content?.held.first { $0.id == selectedHeldId }
	}

	var isWorking: Bool {
		runningAction != nil
	}

	var canAdd: Bool {
		!endpointText.trimmingCharacters(in: .whitespaces).isEmpty && !isWorking
	}

	init(service: NetworkBreakpointControlling, events: NetworkSectionEvents, clock: @escaping () -> Date = Date.init) {
		self.service = service
		self.events = events
		self.clock = clock
	}

	deinit {
		actionTask?.cancel()
	}

	func add() {
		let endpoint = endpointText.trimmingCharacters(in: .whitespaces)
		let request = LensBreakpointRequest(target: .endpoint(endpoint), stage: stage, isOneShot: isOneShot)
		guard canAdd else {
			return
		}
		perform(action: .add, done: String(localized: "Holding \(endpoint) — use the app to make the call")) { [weak self] service in
			try await service.addBreakpoint(request)
			await MainActor.run {
				self?.endpointText = ""
			}
		}
	}

	/// The Traffic tab's "Hold this call": the server resolves the call to the endpoint key the app matches on.
	func hold(callId: String) {
		let request = LensBreakpointRequest(target: .call(id: callId), stage: .response, isOneShot: false)
		perform(action: .hold, done: String(localized: "Holding this call's endpoint — see Breakpoints")) { service in
			try await service.addBreakpoint(request)
		}
	}

	func remove(id: String) {
		perform(action: .remove(id: id), done: String(localized: "Breakpoint removed")) { service in
			try await service.removeBreakpoint(id: id)
		}
	}

	func continueSelected() {
		guard let held = selectedHeld else {
			return
		}
		let statusCode = held.isResponse ? Int(editedStatusText) : nil
		let body = held.canEditBody && editedBody != held.body ? editedBody : nil
		let release = LensHeldRelease.proceed(statusCode: statusCode, body: body)
		perform(action: .release, done: String(localized: "Continued \(held.endpoint)")) { service in
			_ = try await service.release(heldId: held.id, as: release)
		}
	}

	func failSelected() {
		guard let held = selectedHeld else {
			return
		}
		let release = LensHeldRelease.fail(failure)
		perform(action: .release, done: String(localized: "Failed \(held.endpoint) as \(failure.title)")) { service in
			_ = try await service.release(heldId: held.id, as: release)
		}
	}

	func continueAll() {
		perform(action: .continueAll, done: String(localized: "Every held call continued")) { service in
			_ = try await service.releaseAll()
		}
	}

	func setBubble(isHidden: Bool) {
		let done = isHidden ? String(localized: "NetworkLens bubble hidden") : String(localized: "NetworkLens bubble shown")
		perform(action: .bubble(isHidden: isHidden), done: done) { service in
			try await service.setBubble(isHidden: isHidden)
		}
	}

	private func perform(
		action: NetworkBreakpointAction,
		done: String,
		work: @escaping (_ service: NetworkBreakpointControlling) async throws -> Void
	) {
		guard runningAction == nil else {
			events.report(String(localized: "Breakpoints are still busy with the last action — try again in a moment"))
			return
		}
		runningAction = action
		actionFailure = nil
		actionTask = Task { [weak self] in
			guard let self else {
				return
			}
			do {
				try await work(service)
				events.report(done)
			} catch {
				actionFailure = NetworkBreakpointFailure(action: action, message: error.localizedDescription)
				events.report(error.localizedDescription)
			}
			runningAction = nil
			await load()
		}
	}

	private func load() async {
		do {
			let answer = try await service.breakpoints()
			let display = NetworkBreakpointMapper.display(answer, now: clock())
			let isNothingSet = display.breakpoints.isEmpty && display.held.isEmpty
			state = isNothingSet ? .empty(String(localized: "No breakpoints — add an endpoint above, or Hold this call from Traffic")) : .loaded(display)
			if selectedHeld == nil {
				selectedHeldId = display.held.first?.id
			}
		} catch {
			state = .failed(error.localizedDescription)
		}
	}

	private func fillEditor() {
		editedStatusText = selectedHeld?.statusText ?? ""
		editedBody = selectedHeld?.body ?? ""
	}
}

extension NetworkBreakpointsSectionViewModel: NetworkRefreshing {
	/// Every tick while something is held (it auto-continues within a minute), else on the slow tick only.
	func refresh(isFullRefresh: Bool) async {
		let hasHeld = !(state.content?.held.isEmpty ?? true)
		guard isFullRefresh || hasHeld,
			!isWorking
		else {
			return
		}
		let previousSelection = selectedHeldId
		await load()
		if previousSelection == selectedHeldId,
			selectedHeld != nil {
			return
		}
		fillEditor()
	}
}
