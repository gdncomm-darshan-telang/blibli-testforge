import Combine
import Foundation

enum NetworkCallAction: Hashable {
	case mock
	case replay
}

/// What the selected call's Replay / Mock button is doing now, and how its last run ended.
struct NetworkCallActivity: Equatable {
	var runningAction: NetworkCallAction?
	var resultAction: NetworkCallAction?
	var resultMessage: String?
	var isResultSuccess = true
}

@MainActor
protocol NetworkTrafficPresenting: ObservableObject {
	var state: NetworkSectionState<[TrafficCallRowModel]> { get }
	var detail: NetworkSectionState<TrafficCallDetailModel> { get }
	var searchText: String { get set }
	var isMockedOnly: Bool { get set }
	var selectedCallId: String? { get set }
	var callActivity: NetworkCallActivity { get }

	func mockSelectedCall()
	func copyCurl()
	func replaySelectedCall()
	func holdSelectedCall()
}

struct NetworkTrafficActions {
	let copy: (_ text: String) -> Void

	/// Handed to the page: the Breakpoints section owns breakpoints.
	let holdCall: (_ callId: String) -> Void
}

/// Live traffic: the app's captured calls, newest first, filtered on the server by URL text and here by Mocked.
@MainActor
final class NetworkTrafficSectionViewModel: NetworkTrafficPresenting {
	@Published private(set) var state: NetworkSectionState<[TrafficCallRowModel]> = .notLoaded
	@Published private(set) var detail: NetworkSectionState<TrafficCallDetailModel> = .notLoaded
	@Published var isMockedOnly = false {
		didSet {
			applyFilter()
		}
	}

	@Published var searchText = "" {
		didSet {
			scheduleSearch()
		}
	}

	@Published var selectedCallId: String? {
		didSet {
			if callActivity.runningAction == nil {
				callActivity = NetworkCallActivity()
			}
			loadDetail()
		}
	}

	@Published private(set) var callActivity = NetworkCallActivity()

	private let service: NetworkTrafficReading
	private let events: NetworkSectionEvents
	private let actions: NetworkTrafficActions
	private var allRows: [TrafficCallRowModel] = []
	private var detailTask: Task<Void, Never>?
	private var searchTask: Task<Void, Never>?
	private var actionTask: Task<Void, Never>?

	init(service: NetworkTrafficReading, events: NetworkSectionEvents, actions: NetworkTrafficActions) {
		self.service = service
		self.events = events
		self.actions = actions
	}

	deinit {
		detailTask?.cancel()
		searchTask?.cancel()
		actionTask?.cancel()
	}

	func mockSelectedCall() {
		runCallAction(.mock) { service, callId in
			let result = try await service.mockCall(id: callId)
			let done = String(localized: "Rule made from this call (loaded, empty, 500, slow, timeout) — turn it on under Rules")
			return NetworkConsoleMapper.writeMessage(result, done: done)
		}
	}

	func copyCurl() {
		guard let curl = detail.content?.curl else {
			return
		}
		actions.copy(curl)
		events.report(String(localized: "curl copied"))
	}

	func replaySelectedCall() {
		runCallAction(.replay) { service, callId in
			let answer = try await service.replayCall(id: callId)
			return NetworkBreakpointMapper.replayMessage(answer)
		}
	}

	func holdSelectedCall() {
		guard let callId = selectedCallId else {
			return
		}
		actions.holdCall(callId)
	}

	private func runCallAction(
		_ action: NetworkCallAction,
		work: @escaping (_ service: NetworkTrafficReading, _ callId: String) async throws -> String
	) {
		guard callActivity.runningAction == nil,
			let callId = selectedCallId
		else {
			return
		}
		callActivity = NetworkCallActivity(runningAction: action)
		actionTask = Task { [weak self] in
			guard let self else {
				return
			}
			var activity = NetworkCallActivity(resultAction: action)
			do {
				let message = try await work(service, callId)
				activity.resultMessage = message
				events.report(message)
			} catch {
				activity.resultMessage = error.localizedDescription
				activity.isResultSuccess = false
				events.report(error.localizedDescription)
			}
			callActivity = activity
			if action == .mock {
				events.didChange()
			} else {
				await refresh(isFullRefresh: false)
			}
		}
	}

	private func scheduleSearch() {
		searchTask?.cancel()
		searchTask = Task { [weak self] in
			try? await Task.sleep(for: .milliseconds(300))
			guard !Task.isCancelled else {
				return
			}
			await self?.refresh(isFullRefresh: false)
		}
	}

	private func applyFilter() {
		let rows = isMockedOnly ? allRows.filter(\.isMocked) : allRows
		if rows.isEmpty {
			let hint = allRows.isEmpty ? String(localized: "No calls captured yet — use the app") : String(localized: "No mocked calls in this list")
			state = .empty(hint)
		} else {
			state = .loaded(rows)
		}
	}

	private func loadDetail() {
		detailTask?.cancel()
		guard let callId = selectedCallId else {
			detail = .notLoaded
			return
		}
		detail = .loading
		detailTask = Task { [weak self] in
			guard let self else {
				return
			}
			do {
				let answer = try await service.callDetail(id: callId)
				guard !Task.isCancelled else {
					return
				}
				let model = NetworkConsoleMapper.callDetail(answer)
				detail = .loaded(model)
			} catch {
				detail = .failed(error.localizedDescription)
			}
		}
	}
}

extension NetworkTrafficSectionViewModel: NetworkRefreshing {
	func refresh(isFullRefresh: Bool) async {
		do {
			let answer = try await service.calls(matching: searchText, limit: NetworkConsoleConstants.Refresh.callLimit)
			allRows = NetworkConsoleMapper.callRows(answer.calls)
			if let note = answer.note,
				allRows.isEmpty {
				state = .empty(note)
				return
			}
			applyFilter()
		} catch {
			state = .failed(error.localizedDescription)
		}
	}
}
