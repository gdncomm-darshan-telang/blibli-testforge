import Combine
import Foundation

/// Tests › Run all (D-191): shows what the batch will do and what could stop it, then starts it to run hands-free.
/// Whole-class `@MainActor`: it maps one plan to sheet text and forwards Start.
@MainActor
final class BatchPlanViewModel: ObservableObject {
	@Published private(set) var state: BatchPlanState = .hidden
	@Published private(set) var isStarting = false
	@Published private(set) var startFailureMessage: String?

	private let service: TestCaseActing
	private var task: Task<Void, Never>?

	init(service: TestCaseActing) {
		self.service = service
	}

	deinit {
		task?.cancel()
	}

	var isShown: Bool {
		state != .hidden
	}

	func request(caseIds: [String]) {
		guard !caseIds.isEmpty else {
			return
		}
		state = .loading
		isStarting = false
		startFailureMessage = nil
		let service = service
		task?.cancel()
		task = Task { [weak self] in
			do {
				let plan = try await service.planBatch(caseIds: caseIds)
				self?.state = .ready(Self.sheet(for: plan))
			} catch {
				self?.state = .failed(message: error.localizedDescription)
			}
		}
	}

	func dismiss() {
		task?.cancel()
		state = .hidden
	}

	/// D-213: the sheet stays open showing Starting… and closes once the server took the batch; a failure shows in it.
	func start() {
		guard case .ready(let sheet) = state,
			!isStarting
		else {
			return
		}
		isStarting = true
		startFailureMessage = nil
		let service = service
		task = Task { [weak self] in
			do {
				try await service.startBatch(caseIds: sheet.caseIds)
				self?.state = .hidden
			} catch {
				self?.startFailureMessage = error.localizedDescription
			}
			self?.isStarting = false
		}
	}

	static func sheet(for plan: BatchPlan) -> BatchPlanSheetModel {
		var lines = [String(localized: "\(plan.replayCount) replay(s) from recordings, no Claude")]
		if plan.claudeCount > 0 {
			lines.append(String(localized: "\(plan.claudeCount) Claude run(s) for cases without a recording — these use Claude usage"))
		}
		if plan.environmentSwitches.isEmpty {
			lines.append(String(localized: "No environment switch"))
		} else {
			let switches = plan.environmentSwitches.map { String(localized: "to \($0.label) before \($0.beforeCase)") }.joined(separator: ", ")
			lines.append(String(localized: "Environment switches: \(switches) — cases are grouped so each is set up once"))
		}
		if plan.logins > 0 {
			lines.append(String(localized: "Logs in \(plan.logins) time(s) on the way"))
		}
		let title = plan.isHandsFree
			? String(localized: "Run \(plan.caseIds.count) cases hands-free")
			: String(localized: "Run \(plan.caseIds.count) cases — it will stop for you")
		return BatchPlanSheetModel(title: title, lines: lines, stops: plan.stops, isHandsFree: plan.isHandsFree, caseIds: plan.caseIds)
	}
}
