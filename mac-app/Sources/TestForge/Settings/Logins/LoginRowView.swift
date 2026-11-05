import SwiftUI

struct LoginRowView: View {
	let login: TestLogin
	let removalState: LoginRemovalState
	let onRemove: () -> Void

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(login.id)
					.font(.body.monospaced())
				Text(login.hasOtp ? "\(login.email) · OTP stored" : "\(login.email) · OTP asked at run time")
					.font(.caption)
					.foregroundStyle(.secondary)
				if let failure = removalState.failure {
					Label(failure, systemImage: "exclamationmark.triangle")
						.font(.caption)
						.foregroundStyle(.orange)
						.textSelection(.enabled)
						.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsRemoveFailurePrefix + login.id)
				}
			}
			Spacer()
			Button(role: .destructive, action: onRemove) {
				ActionProgressLabel(title: String(localized: "Remove"), busyTitle: String(localized: "Removing…"), isBusy: removalState.isRemoving)
			}
			.buttonStyle(.borderless)
			.disabled(removalState.isRemoving)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsRemovePrefix + login.id)
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsRowPrefix + login.id)
	}
}
