import Combine
import Foundation

@MainActor
protocol NetworkRulesPresenting: ObservableObject {
	var state: NetworkSectionState<[NetworkRuleRowModel]> { get }
	var busyRuleIds: Set<String> { get }
	var selectedRuleId: String? { get set }
	var editor: NetworkVariantEditorViewModel? { get set }
	var selectedRule: NetworkRuleRowModel? { get }

	func setRule(id: String, isEnabled: Bool)
	func activate(ruleId: String, variantId: String)
	func editActiveVariant()
	func edit(variantId: String)
}

/// Which rule a variant editor opens on; the editor never looks the rule up itself.
struct NetworkVariantEditorContext {
	let ruleId: String
	let endpoint: String
	let variant: NetworkVariantModel
	let isActive: Bool
}

/// Rules list: on/off and the answer each rule gives (choosing an answer turns the rule on), plus the editor sheet.
@MainActor
final class NetworkRulesSectionViewModel: NetworkRulesPresenting {
	@Published private(set) var state: NetworkSectionState<[NetworkRuleRowModel]> = .notLoaded
	@Published private(set) var busyRuleIds: Set<String> = []
	@Published var selectedRuleId: String?
	@Published var editor: NetworkVariantEditorViewModel?

	private let service: NetworkRuleEditing
	private let events: NetworkSectionEvents
	private let makeEditor: (_ context: NetworkVariantEditorContext) -> NetworkVariantEditorViewModel
	private var actionTasks: [String: Task<Void, Never>] = [:]

	var selectedRule: NetworkRuleRowModel? {
		state.content?.first { $0.id == selectedRuleId }
	}

	init(
		service: NetworkRuleEditing,
		events: NetworkSectionEvents,
		makeEditor: @escaping (_ context: NetworkVariantEditorContext) -> NetworkVariantEditorViewModel
	) {
		self.service = service
		self.events = events
		self.makeEditor = makeEditor
	}

	deinit {
		actionTasks.values.forEach { $0.cancel() }
	}

	func update(rules: LensRulesResponse) {
		let rows = NetworkConsoleMapper.ruleRows(rules)
		state = rows.isEmpty ? .empty(String(localized: "No rules yet — pick a call under Traffic and choose Mock this call")) : .loaded(rows)
		if selectedRuleId == nil {
			selectedRuleId = rows.first?.id
		}
	}

	func showFailure(message: String) {
		state = .failed(message)
	}

	func setRule(id: String, isEnabled: Bool) {
		guard let rule = state.content?.first(where: { $0.id == id }) else {
			return
		}
		let variantName = rule.activeVariant?.name ?? ""
		perform(ruleId: id) { service in
			if isEnabled {
				let result = try await service.arm(endpoint: rule.endpoint, variantName: variantName)
				let done = String(localized: "\(rule.path) on: \(variantName)")
				return NetworkConsoleMapper.writeMessage(result, done: done)
			}
			let result = try await service.disarm(endpoint: rule.endpoint)
			let done = String(localized: "\(rule.path) off")
			return NetworkConsoleMapper.writeMessage(result, done: done)
		}
	}

	func activate(ruleId: String, variantId: String) {
		guard let rule = state.content?.first(where: { $0.id == ruleId }),
			let variant = rule.variants.first(where: { $0.id == variantId })
		else {
			return
		}
		perform(ruleId: ruleId) { service in
			let result = try await service.arm(endpoint: rule.endpoint, variantName: variant.name)
			let done = String(localized: "\(rule.path) on: \(variant.name)")
			return NetworkConsoleMapper.writeMessage(result, done: done)
		}
	}

	func editActiveVariant() {
		guard let rule = selectedRule,
			let variant = rule.activeVariant
		else {
			return
		}
		let context = NetworkVariantEditorContext(ruleId: rule.id, endpoint: rule.endpoint, variant: variant, isActive: true)
		editor = makeEditor(context)
	}

	func edit(variantId: String) {
		guard let rule = selectedRule,
			let variant = rule.variants.first(where: { $0.id == variantId })
		else {
			return
		}
		let context = NetworkVariantEditorContext(
			ruleId: rule.id,
			endpoint: rule.endpoint,
			variant: variant,
			isActive: variant.id == rule.activeVariantId
		)
		editor = makeEditor(context)
	}

	private func perform(ruleId: String, work: @escaping (_ service: NetworkRuleEditing) async throws -> String) {
		busyRuleIds.insert(ruleId)
		actionTasks[ruleId]?.cancel()
		actionTasks[ruleId] = Task { [weak self] in
			guard let self else {
				return
			}
			do {
				let message = try await work(service)
				events.report(message)
			} catch {
				events.report(error.localizedDescription)
			}
			busyRuleIds.remove(ruleId)
			events.didChange()
		}
	}
}
