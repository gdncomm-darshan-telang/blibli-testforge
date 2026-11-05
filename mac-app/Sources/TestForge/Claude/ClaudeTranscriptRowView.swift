import SwiftUI

struct ClaudeRequestActions {
	let approve: (_ requestId: String, _ isAlways: Bool) -> Void
	let deny: (_ requestId: String) -> Void
	let answer: (_ requestId: String, _ picks: [String: [String]]?) -> Void
}

struct ClaudeTranscriptRowView: View {
	let item: ClaudeTranscriptItem
	let requests: ClaudeRequestStates
	let showsDetails: Bool
	let actions: ClaudeRequestActions

	var body: some View {
		row
			.frame(maxWidth: .infinity, alignment: .leading)
			.accessibilityIdentifier(ClaudeConstants.Accessibility.rowPrefix + item.id)
	}

	private var bubbleShape: RoundedRectangle {
		RoundedRectangle(cornerRadius: ClaudeConstants.Transcript.bubbleCornerRadius)
	}

	@ViewBuilder
	private var row: some View {
		switch item.kind {
			case .user(let text):
				Text(text)
					.textSelection(.enabled)
					.padding(TestForgeConstants.Spacing.medium)
					.background(.tint.opacity(ClaudeConstants.Transcript.userBubbleOpacity), in: bubbleShape)
			case .assistant(let text):
				Text(text)
					.textSelection(.enabled)
			case .tool(let name, let argument, let detail):
				ClaudeDetailRowView(
					summary: "\(name)  \(argument)",
					detail: detail,
					symbolName: "wrench.and.screwdriver",
					isError: false,
					isInitiallyExpanded: showsDetails
				)
			case .toolResult(let text, let isError, let full):
				ClaudeDetailRowView(
					summary: text,
					detail: full,
					symbolName: isError ? "exclamationmark.triangle" : "arrow.turn.down.right",
					isError: isError,
					isInitiallyExpanded: showsDetails
				)
			case .notice(let text, let isError):
				Text(text)
					.font(.callout)
					.foregroundStyle(isError ? Color.red : Color.secondary)
			case .started(let model):
				Text("Claude started · \(model)")
					.font(.callout)
					.foregroundStyle(.secondary)
			case .approval(let requestId, let toolName, let detail):
				ClaudeApprovalCardView(toolName: toolName, detail: detail, status: requests.status(for: requestId)) { isAllowed, isAlways in
					if isAllowed {
						actions.approve(requestId, isAlways)
					} else {
						actions.deny(requestId)
					}
				}
			case .question(let requestId, let questions):
				ClaudeQuestionCardView(questions: questions, status: requests.status(for: requestId)) { picks in
					actions.answer(requestId, picks)
				}
		}
	}
}
