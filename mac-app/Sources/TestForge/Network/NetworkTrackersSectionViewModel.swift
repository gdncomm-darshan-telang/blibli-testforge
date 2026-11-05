import Combine
import Foundation

enum NetworkTrackerReportAction: Hashable {
	case copy
	case save
}

struct NetworkTrackerReportResult: Equatable {
	let message: String
	let isSuccess: Bool
}

@MainActor
protocol NetworkTrackersPresenting: ObservableObject {
	var state: NetworkSectionState<TrackersDisplayModel> { get }
	var fires: NetworkSectionState<[TrackerFireModel]> { get }
	var idsText: String { get set }
	var isAllSessions: Bool { get set }
	var selectedTrackerId: String? { get set }
	var contractName: String? { get }
	var runningReport: NetworkTrackerReportAction? { get }
	var reportResult: NetworkTrackerReportResult? { get }

	func check()
	func chooseContract()
	func clearContract()
	func copyReport()
	func saveReport()
}

struct NetworkTrackersActions {
	let copy: (_ text: String) -> Void
	let chooseContract: () async -> URL?
	let saveReport: (_ markdown: String, _ suggestedFileName: String) async throws -> URL?
}

/// Trackers tab (D-129): which TRMS IDs fired in this launch, against an optional payload contract, plus the DA report.
/// Nothing loads until the person presses Check; after that it follows the page's slow tick so a walk shows up live.
@MainActor
final class NetworkTrackersSectionViewModel: NetworkTrackersPresenting {
	@Published private(set) var state: NetworkSectionState<TrackersDisplayModel> = .notLoaded
	@Published private(set) var fires: NetworkSectionState<[TrackerFireModel]> = .notLoaded
	@Published private(set) var contractName: String?
	@Published private(set) var runningReport: NetworkTrackerReportAction?
	@Published private(set) var reportResult: NetworkTrackerReportResult?
	@Published var idsText = ""
	@Published var isAllSessions = false
	@Published var selectedTrackerId: String? {
		didSet {
			loadFires()
		}
	}

	private let service: NetworkTrackerReading
	private let events: NetworkSectionEvents
	private let actions: NetworkTrackersActions
	private var contract: [String: JSONValue]?
	private var checkTask: Task<Void, Never>?
	private var firesTask: Task<Void, Never>?
	private var actionTask: Task<Void, Never>?

	private var ask: LensTrackerAsk {
		LensTrackerAsk(ids: NetworkTrackerMapper.ids(from: idsText), contract: contract, isAllSessions: isAllSessions)
	}

	init(service: NetworkTrackerReading, events: NetworkSectionEvents, actions: NetworkTrackersActions) {
		self.service = service
		self.events = events
		self.actions = actions
	}

	deinit {
		checkTask?.cancel()
		firesTask?.cancel()
		actionTask?.cancel()
	}

	func check() {
		state = .loading
		checkTask?.cancel()
		checkTask = Task { [weak self] in
			await self?.load()
		}
	}

	/// A contract is `{ "<TRMS ID>": { event?, origin_screen?, required?: [path], expect?: { path: value } } }`.
	func chooseContract() {
		actionTask?.cancel()
		actionTask = Task { [weak self] in
			guard let self,
				let url = await actions.chooseContract()
			else {
				return
			}
			do {
				let data = try Data(contentsOf: url)
				let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
				guard case .object(let rules) = decoded else {
					events.report(String(localized: "A contract is a JSON object keyed by TRMS ID"))
					return
				}
				contract = rules
				contractName = url.lastPathComponent
				check()
			} catch {
				events.report(String(localized: "Could not read \(url.lastPathComponent): \(error.localizedDescription)"))
			}
		}
	}

	func clearContract() {
		contract = nil
		contractName = nil
		check()
	}

	func copyReport() {
		runReport(action: .copy) { [actions] markdown in
			actions.copy(markdown)
			return String(localized: "Tracker report copied as markdown")
		}
	}

	func saveReport() {
		runReport(action: .save) { [actions] markdown in
			let url = try await actions.saveReport(markdown, NetworkConsoleConstants.Trackers.reportFileName)
			return url.map { String(localized: "Saved \($0.lastPathComponent)") }
		}
	}

	/// `deliver` returns the line to show, or nil when the person cancelled (nothing to report).
	private func runReport(action: NetworkTrackerReportAction, deliver: @escaping (_ markdown: String) async throws -> String?) {
		guard runningReport == nil else {
			return
		}
		let currentAsk = ask
		runningReport = action
		reportResult = nil
		actionTask?.cancel()
		actionTask = Task { [weak self] in
			guard let self else {
				return
			}
			do {
				let markdown = try await service.trackersReport(ask: currentAsk)
				if let message = try await deliver(markdown) {
					reportResult = NetworkTrackerReportResult(message: message, isSuccess: true)
					events.report(message)
				}
			} catch {
				reportResult = NetworkTrackerReportResult(message: error.localizedDescription, isSuccess: false)
				events.report(error.localizedDescription)
			}
			runningReport = nil
		}
	}

	private func load() async {
		let currentAsk = ask
		do {
			let answer = try await service.trackers(ask: currentAsk)
			guard !Task.isCancelled else {
				return
			}
			let display = NetworkTrackerMapper.display(answer, isExpectedList: !currentAsk.ids.isEmpty)
			state = display.rows.isEmpty
				? .empty(String(localized: "No trackers fired in this launch — walk the flow, then Check again"))
				: .loaded(display)
			if selectedTrackerId != nil {
				loadFires()
			}
		} catch {
			state = .failed(error.localizedDescription)
		}
	}

	private func loadFires() {
		firesTask?.cancel()
		guard let trackerId = selectedTrackerId else {
			fires = .notLoaded
			return
		}
		if fires.content == nil {
			fires = .loading
		}
		let currentAsk = ask
		firesTask = Task { [weak self] in
			guard let self else {
				return
			}
			do {
				let detail = try await service.trackerFires(id: trackerId, ask: currentAsk)
				guard !Task.isCancelled else {
					return
				}
				let models = NetworkTrackerMapper.fires(detail)
				fires = models.isEmpty ? .empty(String(localized: "\(trackerId) has not fired in this launch")) : .loaded(models)
			} catch {
				fires = .failed(error.localizedDescription)
			}
		}
	}
}

extension NetworkTrackersSectionViewModel: NetworkRefreshing {
	func refresh(isFullRefresh: Bool) async {
		guard isFullRefresh,
			state.content != nil
		else {
			return
		}
		await load()
	}
}
