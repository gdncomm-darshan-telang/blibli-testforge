import Combine
import Foundation

/// Settings › Logins (D-199): the test accounts runs log in with, and the Outlook link that reads prod OTPs.
/// Whole-class `@MainActor`: it only holds a form and forwards it; the Keychain work runs on the server.
@MainActor
final class LoginsViewModel: ObservableObject {
	private static let pendingPollSeconds: UInt64 = 3

	@Published private(set) var state: LoginsState = .loading
	@Published private(set) var mailOtp: MailOtpStatus?
	@Published private(set) var message: String?
	@Published private(set) var isSaving = false
	@Published var draft = TestLoginDraft()
	@Published var pendingRemoval: TestLogin?
	@Published private(set) var mailProgress = MailOtpProgress(busyAction: nil, failure: nil)
	@Published private var removingLoginIds: Set<String> = []
	@Published private var removalFailures: [String: String] = [:]

	private var staticOtpEnvironments = ["uatb"]
	private let service: LoginsManaging
	private let desktop: DesktopActing
	private var loadTask: Task<Void, Never>?
	private var actionTask: Task<Void, Never>?
	private var mailTask: Task<Void, Never>?
	private var removalTasks: [String: Task<Void, Never>] = [:]
	private var mailPollTask: Task<Void, Never>?

	init(service: LoginsManaging, desktop: DesktopActing) {
		self.service = service
		self.desktop = desktop
	}

	deinit {
		loadTask?.cancel()
		actionTask?.cancel()
		mailTask?.cancel()
		removalTasks.values.forEach { $0.cancel() }
		mailPollTask?.cancel()
	}

	let environments = ["uatb", "prod"]

	var canStoreOtp: Bool {
		staticOtpEnvironments.contains(draft.environment)
	}

	var canSave: Bool {
		!isSaving && !draft.profile.isEmpty && draft.email.contains("@") && !draft.password.isEmpty
	}

	func load() {
		loadTask?.cancel()
		loadTask = Task { [weak self] in
			await self?.reload()
		}
	}

	func removalState(for login: TestLogin) -> LoginRemovalState {
		LoginRemovalState(isRemoving: removingLoginIds.contains(login.id), failure: removalFailures[login.id])
	}

	func save() {
		guard canSave else {
			return
		}
		var draft = draft
		if !canStoreOtp {
			draft.otp = ""
		}
		isSaving = true
		message = nil
		actionTask = Task { [weak self, service] in
			do {
				try await service.save(draft: draft)
				self?.message = String(localized: "Saved \(draft.environment)/\(draft.profile) to the Keychain.")
				self?.draft = TestLoginDraft()
				self?.load()
			} catch {
				self?.message = error.localizedDescription
			}
			self?.isSaving = false
		}
	}

	func confirmRemoval() {
		guard let login = pendingRemoval,
			!removingLoginIds.contains(login.id)
		else {
			return
		}
		pendingRemoval = nil
		removingLoginIds.insert(login.id)
		removalFailures[login.id] = nil
		removalTasks[login.id] = Task { [weak self, service] in
			do {
				try await service.remove(login: login)
				await self?.reload()
			} catch {
				self?.removalFailures[login.id] = String(localized: "Couldn't remove: \(error.localizedDescription)")
			}
			self?.removingLoginIds.remove(login.id)
			self?.removalTasks[login.id] = nil
		}
	}

	/// Shows "Opening Outlook…" until the browser opens and the row turns to the pending code.
	func linkMailOtp() {
		runMail(action: .link) { [weak self, service, desktop] in
			let status = try await service.linkMailOtp()
			if let url = status.verificationURL {
				desktop.open(url: url)
			}
			self?.apply(mail: status)
		}
	}

	func copyMailCode() {
		guard let userCode = mailOtp?.userCode else {
			return
		}
		desktop.copy(text: userCode)
	}

	func unlinkMailOtp() {
		runMail(action: .unlink) { [weak self, service] in
			try await service.unlinkMailOtp()
			await self?.reload()
		}
	}

	private func runMail(action: MailOtpAction, work: @escaping @MainActor () async throws -> Void) {
		guard mailProgress.busyAction == nil else {
			return
		}
		mailProgress = MailOtpProgress(busyAction: action, failure: nil)
		mailTask = Task { [weak self] in
			do {
				try await work()
				self?.mailProgress = MailOtpProgress(busyAction: nil, failure: nil)
			} catch {
				self?.mailProgress = MailOtpProgress(busyAction: nil, failure: error.localizedDescription)
			}
		}
	}

	private func reload() async {
		do {
			async let list = service.logins()
			async let mail = service.mailOtpStatus()
			let (loadedList, loadedMail) = try await (list, mail)
			guard !Task.isCancelled else {
				return
			}
			staticOtpEnvironments = loadedList.staticOtpEnvironments
			state = .loaded(loadedList.logins)
			apply(mail: loadedMail)
		} catch {
			state = .failed(message: error.localizedDescription)
		}
	}

	/// While Outlook waits for the code, polls until the sign-in finishes or expires.
	private func apply(mail: MailOtpStatus) {
		mailOtp = mail
		mailPollTask?.cancel()
		guard mail.state == "pending" else {
			return
		}
		mailPollTask = Task { [weak self, service] in
			try? await Task.sleep(nanoseconds: Self.pendingPollSeconds * NSEC_PER_SEC)
			guard !Task.isCancelled else {
				return
			}
			do {
				let status = try await service.mailOtpStatus()
				self?.mailProgress = MailOtpProgress(busyAction: nil, failure: nil)
				self?.apply(mail: status)
			} catch {
				// Keep polling the same pending sign-in; the row says why it hasn't moved on.
				let failure = String(localized: "Couldn't check the sign-in (\(error.localizedDescription)) — retrying…")
				self?.mailProgress = MailOtpProgress(busyAction: nil, failure: failure)
				self?.apply(mail: mail)
			}
		}
	}
}
