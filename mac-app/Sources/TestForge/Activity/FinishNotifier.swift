import AppKit
import UserNotifications

struct FinishNotice: Equatable {
	let title: String
	let body: String

	/// A Claude session waiting on the person (D-147): clicking opens that session instead of Results.
	var claudeSessionId: String?

	/// A heads-up while recording a macro (D-171): clicking only brings the TestForge forward.
	var isAlertOnly = false
}

@MainActor
protocol FinishNotifying: AnyObject {
	/// Called when the person clicks a notice.
	var openResults: (() -> Void)? { get set }

	/// Called when the person clicks a notice about a Claude session waiting on them.
	var openClaudeSession: ((String) -> Void)? { get set }

	/// Asks macOS for permission once; later calls are no-ops for the system.
	func prepare()

	func post(notice: FinishNotice)
}

/// A bare `swift run` executable has no bundle id, and `UNUserNotificationCenter` traps without one, so the center is optional.
@MainActor
final class UserNotificationNotifier: NSObject, FinishNotifying {
	var openResults: (() -> Void)?
	var openClaudeSession: ((String) -> Void)?

	private let center: UNUserNotificationCenter?
	private let application: NSApplication

	init(center: UNUserNotificationCenter?, application: NSApplication) {
		self.center = center
		self.application = application
		super.init()
		center?.delegate = self
	}

	func prepare() {
		center?.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
			// Denied permission only means no banners; the Dock badge and menu bar still show the result.
		}
	}

	func post(notice: FinishNotice) {
		let content = UNMutableNotificationContent()
		content.title = notice.title
		content.body = notice.body
		content.sound = .default
		if let claudeSessionId = notice.claudeSessionId {
			content.userInfo = [Self.sessionKey: claudeSessionId]
		}
		if notice.isAlertOnly {
			content.userInfo = [Self.alertOnlyKey: true]
		}
		let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
		center?.add(request)
	}

	nonisolated private static let sessionKey = "claudeSessionId"
	nonisolated private static let alertOnlyKey = "alertOnly"

	private func handleOpen(claudeSessionId: String?, isAlertOnly: Bool) {
		application.activate(ignoringOtherApps: true)
		if isAlertOnly {
			return
		}
		if let claudeSessionId {
			openClaudeSession?(claudeSessionId)
			return
		}
		openResults?()
	}
}

extension UserNotificationNotifier: UNUserNotificationCenterDelegate {
	/// Shows the banner even while the app is in front; a run often finishes while the person watches the Simulator.
	nonisolated func userNotificationCenter(
		_ center: UNUserNotificationCenter,
		willPresent notification: UNNotification
	) async -> UNNotificationPresentationOptions {
		[.banner, .sound]
	}

	nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
		let userInfo = response.notification.request.content.userInfo
		let claudeSessionId = userInfo[Self.sessionKey] as? String
		let isAlertOnly = userInfo[Self.alertOnlyKey] as? Bool ?? false
		await MainActor.run {
			handleOpen(claudeSessionId: claudeSessionId, isAlertOnly: isAlertOnly)
		}
	}
}
