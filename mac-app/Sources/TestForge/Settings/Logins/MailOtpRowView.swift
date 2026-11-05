import SwiftUI

struct MailOtpActions {
	let link: () -> Void
	let unlink: () -> Void
	let copyCode: () -> Void
}

/// D-048: whether prod runs can read their OTP from Outlook instead of asking in a popup.
struct MailOtpRowView: View {
	let status: MailOtpStatus?
	let progress: MailOtpProgress
	let actions: MailOtpActions

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text("Email OTP")
					.font(.body.weight(.medium))
				detail
				if let failure = progress.failure {
					Label(failure, systemImage: "exclamationmark.triangle")
						.font(.caption)
						.foregroundStyle(.orange)
						.textSelection(.enabled)
						.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsMailFailure)
				}
			}
			Spacer()
			button
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsMailOtp)
	}

	@ViewBuilder
	private var detail: some View {
		switch status?.state {
			case "linked":
				Text("\(status?.username ?? "Outlook") · reads codes from \(status?.sender ?? "Blibli")")
					.font(.caption)
					.foregroundStyle(.secondary)
			case "pending":
				HStack(spacing: TestForgeConstants.Spacing.small) {
					Text("Sign in in your browser with code \(status?.userCode ?? "")")
						.font(.caption)
						.textSelection(.enabled)
					Button("Copy code", systemImage: "doc.on.doc", action: actions.copyCode)
						.labelStyle(.iconOnly)
						.buttonStyle(.borderless)
						.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsMailCode)
				}
			default:
				Text(status?.error.map { "Not linked — \($0)" } ?? "Not linked — prod OTPs are asked in a popup during the run.")
					.font(.caption)
					.foregroundStyle(.secondary)
		}
	}

	@ViewBuilder
	private var button: some View {
		if status?.state == "linked" {
			Button(role: .destructive, action: actions.unlink) {
				ActionProgressLabel(title: String(localized: "Unlink"), busyTitle: String(localized: "Unlinking…"), isBusy: progress.busyAction == .unlink)
			}
			.disabled(isBusy)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsMailUnlink)
		} else if status?.state != "pending" {
			Button(action: actions.link) {
				ActionProgressLabel(
					title: String(localized: "Link Outlook"),
					busyTitle: String(localized: "Opening Outlook…"),
					isBusy: progress.busyAction == .link
				)
			}
			.disabled(isBusy)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsMailLink)
		}
	}

	private var isBusy: Bool {
		progress.busyAction != nil
	}
}
