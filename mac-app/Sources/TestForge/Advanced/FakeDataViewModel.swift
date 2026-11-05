import Combine
import Foundation

enum CallBodyState: Equatable {
	case notSelected
	case loading
	case loaded(String)
	case failed(String)
}

/// Fake data panel: NetworkLens rules from the `mocks` slice, the master switch from `status`, recent calls from `trace`.
/// Whole-class `@MainActor`: every method only maps slices to published state; requests run in the service.
@MainActor
final class FakeDataViewModel: ObservableObject {
	@Published private(set) var content = FakeDataMapper.content(status: nil, mocks: nil, trace: nil)
	@Published private(set) var variantDetail: MockVariantDetailModel?
	@Published private(set) var callBody: CallBodyState = .notSelected
	@Published private(set) var busyRuleIds: Set<String> = []
	@Published private(set) var actionMessage: String?
	@Published var isNetworkLensConfirmationShown = false
	/// D-213: the master switch's requested value, shown until the `status` slice agrees, so it doesn't snap back.
	@Published private(set) var pendingMocking: Bool?
	@Published private(set) var isEnablingNetworkLens = false

	@Published var selectedRuleId: String? {
		didSet {
			refreshVariantDetail()
		}
	}

	@Published var selectedCallId: String? {
		didSet {
			loadCallBody()
		}
	}

	private let store: StateStore
	private let service: MockActing
	private var rules: [MockRule] = []
	private var cancellables = Set<AnyCancellable>()
	/// Keyed by rule id (or the switch's own key) so toggling two rules at once lets both finish.
	private var actionTasks: [String: Task<Void, Never>] = [:]

	private var bodyTask: Task<Void, Never>?

	init(store: StateStore, service: MockActing) {
		self.store = store
		self.service = service
		observeStore()
	}

	deinit {
		actionTasks.values.forEach { $0.cancel() }
		bodyTask?.cancel()
	}

	var isMockingSwitchOn: Bool {
		pendingMocking ?? content.status.isMockingEnabled
	}

	var isSessionBusy: Bool {
		pendingMocking != nil || isEnablingNetworkLens
	}

	func setMocking(isEnabled: Bool) {
		guard !isSessionBusy else {
			return
		}
		pendingMocking = isEnabled
		perform { [weak self] service in
			try await service.setMocking(isEnabled: isEnabled)
			await self?.waitForMocking(isEnabled: isEnabled)
		}
	}

	func setRule(id: String, isEnabled: Bool) {
		busyRuleIds.insert(id)
		perform(ruleId: id) { service in
			try await service.setRule(id: id, isEnabled: isEnabled)
		}
	}

	func activate(ruleId: String, variantId: String) {
		busyRuleIds.insert(ruleId)
		perform(ruleId: ruleId) { service in
			try await service.activate(ruleId: ruleId, variantId: variantId)
		}
	}

	func requestNetworkLens() {
		isNetworkLensConfirmationShown = true
	}

	func enableNetworkLens() {
		guard !isSessionBusy else {
			return
		}
		isEnablingNetworkLens = true
		perform { service in
			try await service.enableNetworkLens()
		}
	}

	func dismissMessage() {
		actionMessage = nil
	}

	private func perform(ruleId: String? = nil, request: @escaping (MockActing) async throws -> Void) {
		actionMessage = nil
		let service = service
		let taskKey = ruleId ?? "session"
		actionTasks[taskKey]?.cancel()
		actionTasks[taskKey] = Task { [weak self] in
			do {
				try await request(service)
			} catch {
				self?.actionMessage = error.localizedDescription
			}
			self?.finishAction(taskKey: taskKey, ruleId: ruleId)
		}
	}

	private func finishAction(taskKey: String, ruleId: String?) {
		actionTasks[taskKey] = nil
		if let ruleId {
			busyRuleIds.remove(ruleId)
		} else {
			pendingMocking = nil
			isEnablingNetworkLens = false
		}
	}

	private func waitForMocking(isEnabled: Bool) async {
		for _ in 0..<TestForgeConstants.FeedbackReview.settlePollAttempts {
			guard content.status.isMockingEnabled != isEnabled,
				!Task.isCancelled
			else {
				return
			}
			try? await Task.sleep(nanoseconds: TestForgeConstants.FeedbackReview.settlePollNanoseconds)
		}
	}

	private func loadCallBody() {
		bodyTask?.cancel()
		guard let callId = selectedCallId else {
			callBody = .notSelected
			return
		}
		callBody = .loading
		let service = service
		bodyTask = Task { [weak self] in
			do {
				let body = try await service.responseBody(callId: callId)
				self?.callBody = .loaded(body)
			} catch {
				guard !Task.isCancelled else {
					return
				}
				self?.callBody = .failed(error.localizedDescription)
			}
		}
	}

	private func refreshVariantDetail() {
		let rule = rules.first { $0.id == selectedRuleId }
		guard let rule else {
			variantDetail = nil
			return
		}
		let variantId = rule.activeVariantId ?? rule.variants.first?.id ?? ""
		variantDetail = FakeDataMapper.detail(rule: rule, variantId: variantId)
	}

	private func observeStore() {
		store.$slices
			.receive(on: DispatchQueue.main)
			.sink { [weak self] _ in
				self?.readSlices()
			}
			.store(in: &cancellables)
	}

	private func readSlices() {
		let status = store.value(of: .status, as: LensStatus.self)
		let mocks = store.value(of: .mocks, as: MockState.self)
		let trace = store.value(of: .trace, as: TraceState.self)
		rules = mocks?.rules ?? []
		let newContent = FakeDataMapper.content(status: status, mocks: mocks, trace: trace)
		if newContent != content {
			content = newContent
			refreshVariantDetail()
		}
	}
}
