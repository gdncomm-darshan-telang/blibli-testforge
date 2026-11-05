import SwiftUI

/// A tool Claude wants to run; answered once, then shows the outcome.
struct ClaudeApprovalCardView: View {
	let toolName: String
	let detail: String
	let status: ClaudeRequestStatus
	let decide: (_ isAllowed: Bool, _ isAlways: Bool) -> Void

	var body: some View {
		GroupBox {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
				if !detail.isEmpty {
					ScrollView {
						Text(detail)
							.font(.callout.monospaced())
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
					.frame(maxHeight: ClaudeConstants.Transcript.approvalDetailMaxHeight)
				}
				footer
			}
			.padding(TestForgeConstants.Spacing.small)
		} label: {
			Label("Claude wants to use \(toolName)", systemImage: "hand.raised")
		}
	}

	@ViewBuilder
	private var footer: some View {
		if let outcome = status.outcome {
			Text(outcome)
				.foregroundStyle(.secondary)
		} else {
			HStack {
				Button {
					decide(true, false)
				} label: {
					ActionProgressLabel(title: String(localized: "Approve"), busyTitle: String(localized: "Approving…"), isBusy: isPending(.approve))
				}
				.keyboardShortcut(.defaultAction)
				.accessibilityIdentifier(ClaudeConstants.Accessibility.approveButton)
				Button {
					decide(true, true)
				} label: {
					ActionProgressLabel(title: String(localized: "Always allow"), busyTitle: String(localized: "Allowing…"), isBusy: isPending(.alwaysAllow))
				}
				.help("Allow this tool in this repo from now on")
				.accessibilityIdentifier(ClaudeConstants.Accessibility.alwaysAllowButton)
				Spacer()
				Button(role: .destructive) {
					decide(false, false)
				} label: {
					ActionProgressLabel(title: String(localized: "Deny"), busyTitle: String(localized: "Denying…"), isBusy: isPending(.deny))
				}
				.accessibilityIdentifier(ClaudeConstants.Accessibility.denyButton)
			}
			.disabled(status.pendingAction != nil)
			if let errorMessage = status.errorMessage {
				Label(errorMessage, systemImage: "exclamationmark.triangle")
					.font(.callout)
					.foregroundStyle(.red)
					.textSelection(.enabled)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.claudeApprovalFailure)
			}
		}
	}

	private func isPending(_ action: ClaudeRequestAction) -> Bool {
		status.pendingAction == action
	}
}
