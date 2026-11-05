import Combine
import Foundation

enum DeeplinkCatalogState: Equatable {
	case loading
	case loaded
	case failed(message: String)
}

enum DeeplinkOpenState: Equatable {
	case idle
	case opening
	case opened(message: String)
	case failed(message: String)
}

/// A saved link or a recent open, ready to show as one row.
struct DeeplinkEntryRow: Equatable, Identifiable {
	let id: String
	let title: String
	let url: String
	let detail: String?
	let isSaved: Bool
}

/// D-157: build a link from the app's route list (or type one) and open it in the running app on the test simulator.
/// Whole-class `@MainActor`: every method only maps service answers to published state; requests run in the service.
@MainActor
final class DeeplinksSectionViewModel: ObservableObject {
	@Published private(set) var catalogState: DeeplinkCatalogState = .loading
	@Published private(set) var openState: DeeplinkOpenState = .idle
	@Published private(set) var paramValues: [String: String] = [:]
	@Published private(set) var matchText: String?
	@Published private(set) var problemText: String?
	@Published private(set) var savedRows: [DeeplinkEntryRow] = []
	@Published private(set) var recentRows: [DeeplinkEntryRow] = []
	@Published private(set) var queryItems: [DeeplinkQueryItem] = []

	/// A test or scan holds the phone; opening a link under it would break the run.
	@Published private(set) var isLocked = false

	@Published var searchText = ""
	@Published var selectedRouteId: String? {
		didSet {
			paramValues = [:]
			composeLink()
		}
	}
	@Published var link = "" {
		didSet {
			scheduleMatch()
		}
	}

	private let service: DeeplinkProviding
	private let store: StateStore
	private var routes: [DeeplinkRoute] = []
	private var appVersion: String?
	private var loadTask: Task<Void, Never>?
	private var matchTask: Task<Void, Never>?
	private var actionTask: Task<Void, Never>?
	private var cancellables = Set<AnyCancellable>()

	init(service: DeeplinkProviding, store: StateStore) {
		self.service = service
		self.store = store
		observeLock()
	}

	deinit {
		loadTask?.cancel()
		matchTask?.cancel()
		actionTask?.cancel()
	}

	var filteredRoutes: [DeeplinkRoute] {
		let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
		guard !query.isEmpty else {
			return routes
		}
		return routes.filter { route in
			route.description.lowercased().contains(query) || route.template.lowercased().contains(query)
		}
	}

	/// The search shows only a short list under the field; the rest are reached by typing more.
	var routeSearchContent: DeeplinkRouteSearchContent {
		let query = searchText.trimmingCharacters(in: .whitespaces)
		guard selectedRoute == nil,
			!query.isEmpty
		else {
			return DeeplinkRouteSearchContent(selectedTitle: selectedRoute?.description, matches: [], footnote: nil)
		}
		let matches = filteredRoutes
		let shown = Array(matches.prefix(TestForgeConstants.SimulatorControl.deeplinkRouteMatchLimit))
		let footnote: String?
		if matches.isEmpty {
			footnote = String(localized: "No screen matches “\(query)”. Type the link yourself below.")
		} else if matches.count > shown.count {
			footnote = String(localized: "\(matches.count - shown.count) more — keep typing to narrow it down.")
		} else {
			footnote = nil
		}
		return DeeplinkRouteSearchContent(selectedTitle: nil, matches: shown, footnote: footnote)
	}

	func selectRoute(id: String) {
		selectedRouteId = id
		searchText = ""
	}

	func clearRoute() {
		selectedRouteId = nil
		link = ""
	}

	var selectedRoute: DeeplinkRoute? {
		routes.first { $0.id == selectedRouteId }
	}

	var paramFields: [DeeplinkParamField] {
		guard let route = selectedRoute else {
			return []
		}
		return route.params.map { param in
			guard param.name == "rest" else {
				return DeeplinkParamField(
					name: param.name,
					label: param.name,
					prompt: String(localized: "fills {\(param.name)} in \(route.template)"),
					help: String(localized: "Replaces {\(param.name)} in the link.")
				)
			}
			let prefix = route.template.components(separatedBy: "{rest}").first ?? route.template
			return DeeplinkParamField(
				name: param.name,
				label: String(localized: "More path (optional)"),
				prompt: String(localized: "added after \(prefix), e.g. /detail. Leave empty to open \(prefix) as is"),
				help: String(localized: "This route accepts anything after \(prefix). Query parameters go in the rows below the link.")
			)
		}
	}

	var queryFieldsContent: DeeplinkQueryFieldsContent {
		let keyChoices = DeeplinkVersionKey.allCases.map { DeeplinkQueryKeyChoice(title: $0.title, key: $0.rawValue) }
		let rows = queryItems.map { item in
			let choices = DeeplinkVersionKey.matching(item.name).map { DeeplinkVersionPresets.values(for: $0, appVersion: appVersion) } ?? []
			return DeeplinkQueryRowContent(item: item, valueChoices: choices)
		}
		return DeeplinkQueryFieldsContent(rows: rows, keyChoices: keyChoices, preview: queryPreview)
	}

	var hasEntries: Bool {
		!savedRows.isEmpty || !recentRows.isEmpty
	}

	/// The full link when query parameters change it; nil when the link field already says it all.
	var queryPreview: String? {
		let full = fullLink
		return full == trimmedLink ? nil : full
	}

	func addQueryItem() {
		queryItems.append(DeeplinkQueryItem(id: UUID(), name: "", value: ""))
	}

	func changeQueryItem(_ item: DeeplinkQueryItem) {
		guard let index = queryItems.firstIndex(where: { $0.id == item.id }) else {
			return
		}
		queryItems[index] = item
		scheduleMatch()
	}

	func removeQueryItem(id: UUID) {
		queryItems.removeAll { $0.id == id }
		scheduleMatch()
	}

	var canOpen: Bool {
		!isLocked && openState != .opening && problemText == nil && !trimmedLink.isEmpty
	}

	var canSave: Bool {
		problemText == nil && !trimmedLink.isEmpty
	}

	func load() {
		loadTask?.cancel()
		let service = service
		loadTask = Task { [weak self] in
			do {
				let catalog = try await service.catalog()
				self?.apply(catalog: catalog)
			} catch {
				self?.catalogState = .failed(message: error.localizedDescription)
			}
		}
	}

	func setParam(name: String, value: String) {
		paramValues[name] = value
		composeLink()
	}

	/// Opens `url` when given (a saved or recent row), else the link being built.
	func open(url: String? = nil) {
		let target = url ?? fullLink
		guard !target.isEmpty else {
			return
		}
		openState = .opening
		let service = service
		actionTask?.cancel()
		actionTask = Task { [weak self] in
			do {
				let result = try await service.open(url: target)
				let message = result.matched.map { String(localized: "Opened — caught by \($0)") } ?? String(localized: "Opened in the app")
				self?.openState = .opened(message: message)
			} catch {
				self?.openState = .failed(message: error.localizedDescription)
			}
			self?.load()
		}
	}

	func saveCurrent() {
		let url = fullLink
		guard canSave else {
			return
		}
		let name = selectedRoute?.description ?? url
		perform { service in
			try await service.save(name: name, url: url)
		}
	}

	func removeSaved(id: String) {
		perform { service in
			try await service.removeSaved(id: id)
		}
	}

	private var trimmedLink: String {
		link.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private var fullLink: String {
		DeeplinkQueryComposer.link(trimmedLink, adding: queryItems)
	}

	private func perform(request: @escaping (DeeplinkProviding) async throws -> Void) {
		let service = service
		actionTask?.cancel()
		actionTask = Task { [weak self] in
			do {
				try await request(service)
			} catch {
				self?.openState = .failed(message: error.localizedDescription)
			}
			self?.load()
		}
	}

	private func apply(catalog: DeeplinkCatalog) {
		routes = catalog.routes
		appVersion = catalog.appVersion
		savedRows = catalog.saved.map { saved in
			DeeplinkEntryRow(id: saved.id, title: saved.name, url: saved.url, detail: nil, isSaved: true)
		}
		let recent = catalog.history.prefix(TestForgeConstants.SimulatorControl.deeplinkRecentLimit)
		recentRows = recent.enumerated().map { index, opening in
			let detail = opening.isOpened ? opening.matched : opening.error
			return DeeplinkEntryRow(id: "recent-\(index)", title: opening.url, url: opening.url, detail: detail, isSaved: false)
		}
		catalogState = .loaded
	}

	private func composeLink() {
		guard let route = selectedRoute else {
			return
		}
		var composed = route.template
		for param in route.params {
			let value = paramValues[param.name] ?? ""
			composed = composed.replacingOccurrences(of: "{\(param.name)}", with: value)
		}
		link = composed
	}

	private func scheduleMatch() {
		matchTask?.cancel()
		let url = fullLink
		guard !url.isEmpty else {
			matchText = nil
			problemText = nil
			return
		}
		let service = service
		let delay = Duration.milliseconds(TestForgeConstants.SimulatorControl.deeplinkMatchDelayMilliseconds)
		matchTask = Task { [weak self] in
			try? await Task.sleep(for: delay)
			guard !Task.isCancelled,
				let match = try? await service.match(url: url)
			else {
				return
			}
			self?.problemText = match.problem
			self?.matchText = Self.matchDescription(for: match, typed: url)
		}
	}

	/// The list is the app's local DeeplinkList.txt; its live router config can still catch a link the list doesn't.
	/// A link the server rewrites (UAT-B web link → `blibli://`) leads with what it will actually open.
	private static func matchDescription(for match: DeeplinkMatch, typed: String) -> String {
		let route: String
		if let first = match.matches.first {
			route = String(localized: "Caught by \(first.description) · \(first.handlerClass)")
		} else {
			route = String(localized: "No route in the app's list catches this — the app may still handle it.")
		}
		guard let opened = match.url,
			opened != typed
		else {
			return route
		}
		return String(localized: "Opens as \(opened) · \(route)")
	}

	private func observeLock() {
		let store = store
		store.$slices
			.receive(on: RunLoop.main)
			.sink { [weak self] _ in
				let isRunning = store.value(of: .queue, as: QueueState.self)?.hasActiveTask ?? false
				let isScanning = store.value(of: .scan, as: ScanState.self)?.isActive ?? false
				self?.isLocked = isRunning || isScanning
			}
			.store(in: &cancellables)
	}
}
