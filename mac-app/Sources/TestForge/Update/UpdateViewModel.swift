import Foundation

enum UpdateActivity: Equatable {
	case idle
	case checking
	case pulling
	case building

	var isBusy: Bool {
		self != .idle
	}
}

@MainActor
protocol UpdatePresenting: ObservableObject {
	var status: UpdateStatus? { get }
	var activity: UpdateActivity { get }

	/// The last failure, shown next to the control that caused it.
	var message: String? { get }

	var canUpdate: Bool { get }
	func check()
	func update()
}

/// Settings › Project › Updates and the app menu: is there a newer master, and one click to pull, rebuild and reopen (D-217).
@MainActor
final class UpdateViewModel: UpdatePresenting {
	@Published private(set) var status: UpdateStatus?
	@Published private(set) var activity: UpdateActivity = .idle
	@Published private(set) var message: String?

	private let service: AppUpdating
	private let system: AppRelaunching
	private var task: Task<Void, Never>?

	init(service: AppUpdating, system: AppRelaunching) {
		self.service = service
		self.system = system
	}

	deinit {
		task?.cancel()
	}

	var canUpdate: Bool {
		if case .available = status?.state {
			return !activity.isBusy
		}
		return false
	}

	/// The menu item: names the update when one is waiting.
	var menuTitle: String {
		if case .available(let count) = status?.state {
			return String(localized: "Update TestForge… (\(count) new)")
		}
		return String(localized: "Check for Updates…")
	}

	func check() {
		guard !activity.isBusy else {
			return
		}
		activity = .checking
		message = nil
		task = Task { [weak self] in
			await self?.runCheck(reportsFailure: true)
		}
	}

	/// At launch: a quiet look, so the menu can say "update waiting" without a failed check ever nagging.
	func checkQuietly() {
		guard !activity.isBusy else {
			return
		}
		activity = .checking
		task = Task { [weak self] in
			await self?.runCheck(reportsFailure: false)
		}
	}

	func update() {
		guard canUpdate else {
			return
		}
		message = nil
		activity = .pulling
		task = Task { [weak self] in
			await self?.runUpdate()
		}
	}

	private func runCheck(reportsFailure: Bool) async {
		do {
			status = try await service.checkStatus()
		} catch {
			if reportsFailure {
				message = error.localizedDescription
			}
		}
		activity = .idle
	}

	private func runUpdate() async {
		do {
			let app = try await service.update { [weak self] phase in
				self?.activity = phase == .pulling ? .pulling : .building
			}
			system.relaunch(at: app)
		} catch {
			message = error.localizedDescription
			activity = .idle
			if let refreshed = try? await service.checkStatus() {
				status = refreshed
			}
		}
	}
}
