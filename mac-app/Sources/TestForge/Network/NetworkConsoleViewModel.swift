import Combine
import Foundation
import UniformTypeIdentifiers

enum NetworkConsoleTab: String, CaseIterable, Identifiable {
	case traffic
	case rules
	case breakpoints
	case trackers

	var id: String { rawValue }

	var title: String {
		switch self {
			case .traffic:
				return String(localized: "Traffic")
			case .rules:
				return String(localized: "Rules & scenarios")
			case .breakpoints:
				return String(localized: "Breakpoints")
			case .trackers:
				return String(localized: "Trackers")
		}
	}
}

/// Network console page (D-128): builds every section, runs the refresh tick while visible, and refreshes all after any change.
/// Health and rules are fetched once here and handed to both sections that show them — the rules answer carries every body.
@MainActor
final class NetworkConsoleViewModel: ObservableObject {
	@Published var selectedTab: NetworkConsoleTab = .traffic
	@Published private(set) var message: String?

	let health: NetworkHealthSectionViewModel
	let guardrails: NetworkGuardrailsSectionViewModel
	let traffic: NetworkTrafficSectionViewModel
	let rules: NetworkRulesSectionViewModel
	let scenarios: NetworkScenariosSectionViewModel
	let trackers: NetworkTrackersSectionViewModel
	let breakpoints: NetworkBreakpointsSectionViewModel

	private let service: NetworkConsoleServing
	private let refreshing: [NetworkRefreshing]
	private var tickTask: Task<Void, Never>?
	private var refreshTask: Task<Void, Never>?
	private var tickCount = 0
	private var latestRules: LensRulesResponse?

	init(service: NetworkConsoleServing, copy: @escaping (_ text: String) -> Void, trackerActions: NetworkTrackersActions) {
		self.service = service
		let relay = NetworkEventRelay()
		let events = NetworkSectionEvents(
			didChange: { relay.target?.refreshNow() },
			report: { message in relay.target?.show(message: message) }
		)
		health = NetworkHealthSectionViewModel(service: service, events: events)
		guardrails = NetworkGuardrailsSectionViewModel(service: service, events: events)
		let trafficActions = NetworkTrafficActions(copy: copy) { callId in
			relay.target?.hold(callId: callId)
		}
		traffic = NetworkTrafficSectionViewModel(service: service, events: events, actions: trafficActions)
		let editorActions = NetworkVariantEditorActions(
			finish: { message in relay.target?.closeEditor(message: message) },
			cancel: { relay.target?.closeEditor(message: nil) }
		)
		rules = NetworkRulesSectionViewModel(service: service, events: events) { context in
			NetworkVariantEditorViewModel(service: service, context: context, actions: editorActions)
		}
		scenarios = NetworkScenariosSectionViewModel(service: service, events: events)
		trackers = NetworkTrackersSectionViewModel(service: service, events: events, actions: trackerActions)
		breakpoints = NetworkBreakpointsSectionViewModel(service: service, events: events)
		refreshing = [traffic, guardrails, scenarios, trackers, breakpoints]
		relay.target = self
	}

	deinit {
		tickTask?.cancel()
		refreshTask?.cancel()
	}

	func start() {
		guard tickTask == nil else {
			return
		}
		tickTask = Task { [weak self] in
			while !Task.isCancelled {
				await self?.tick()
				try? await Task.sleep(for: NetworkConsoleConstants.Refresh.tickInterval)
			}
		}
	}

	func stop() {
		tickTask?.cancel()
		tickTask = nil
	}

	func refreshNow() {
		refreshTask?.cancel()
		refreshTask = Task { [weak self] in
			await self?.refresh(isFullRefresh: true)
		}
	}

	func dismissMessage() {
		message = nil
	}

	private func hold(callId: String) {
		breakpoints.hold(callId: callId)
		selectedTab = .breakpoints
	}

	private func show(message: String) {
		self.message = message
	}

	private func closeEditor(message: String?) {
		rules.editor = nil
		if let message {
			show(message: message)
			refreshNow()
		}
	}

	private func tick() async {
		let isFullRefresh = tickCount % NetworkConsoleConstants.Refresh.slowTickEvery == 0
		tickCount += 1
		await refresh(isFullRefresh: isFullRefresh)
	}

	private func refresh(isFullRefresh: Bool) async {
		await refreshHealthAndRules(isFullRefresh: isFullRefresh)
		for section in refreshing {
			await section.refresh(isFullRefresh: isFullRefresh)
		}
	}

	private func refreshHealthAndRules(isFullRefresh: Bool) async {
		do {
			let healthAnswer = try await service.health()
			let rulesAnswer = isFullRefresh ? try await service.rules() : nil
			if let rulesAnswer {
				rules.update(rules: rulesAnswer)
				latestRules = rulesAnswer
			}
			health.update(health: healthAnswer, rules: latestRules)
		} catch {
			health.showFailure(message: error.localizedDescription)
			if isFullRefresh {
				rules.showFailure(message: error.localizedDescription)
			}
		}
	}

}

/// Breaks the init-time cycle: section callbacks are built before `self` exists, so they reach the page through this.
@MainActor
private final class NetworkEventRelay {
	weak var target: NetworkConsoleViewModel?
}

/// Builds the Network console's whole graph; a caller conforms and calls it rather than constructing a factory.
@MainActor
protocol NetworkConsoleOpening {}

extension NetworkConsoleOpening {
	static func makeNetworkConsoleViewModel(service: NetworkConsoleServing, desktop: DesktopActing) -> NetworkConsoleViewModel {
		let trackerActions = NetworkTrackersActions(
			copy: { text in desktop.copy(text: text) },
			chooseContract: { await desktop.chooseFile(prompt: String(localized: "Use contract"), contentTypes: [.json]) },
			saveReport: { markdown, fileName in try await desktop.saveText(text: markdown, suggestedFileName: fileName) }
		)
		return NetworkConsoleViewModel(
			service: service,
			copy: { text in desktop.copy(text: text) },
			trackerActions: trackerActions
		)
	}
}
