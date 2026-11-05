import SwiftUI

/// Above the message box: a banner when Claude ended its turn on a question, and one-click replies (D-147).
struct ClaudeQuickRepliesView: View {
	let replies: [String]
	let isAwaitingReply: Bool
	let send: (String) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			if isAwaitingReply {
				Label("Claude is waiting for your reply", systemImage: "questionmark.bubble")
					.font(.callout.bold())
					.foregroundStyle(Color.accentColor)
					.accessibilityIdentifier(ClaudeConstants.Accessibility.awaitingReplyBanner)
			}
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: TestForgeConstants.Spacing.small) {
					ForEach(Array(replies.enumerated()), id: \.offset) { index, reply in
						Button(reply) {
							send(reply)
						}
						.buttonStyle(.bordered)
						.controlSize(.small)
						.accessibilityIdentifier(ClaudeConstants.Accessibility.quickReplyPrefix + String(index))
					}
				}
			}
		}
		.padding(.horizontal, TestForgeConstants.Spacing.medium)
		.padding(.top, TestForgeConstants.Spacing.small)
	}
}
