import SwiftUI

struct ClaudeComposerView<ViewModel: ClaudeSectionPresenting>: View {
	@ObservedObject var viewModel: ViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			if let errorMessage = viewModel.errorMessage {
				Text(errorMessage)
					.font(.callout)
					.foregroundStyle(.red)
			}
			HStack(alignment: .bottom, spacing: TestForgeConstants.Spacing.medium) {
				TextField("Message Claude — ⌘↩ to send", text: $viewModel.draft, axis: .vertical)
					.textFieldStyle(.roundedBorder)
					.lineLimit(ClaudeConstants.Composer.lineRange)
					.frame(minHeight: ClaudeConstants.Composer.minHeight, maxHeight: ClaudeConstants.Composer.maxHeight)
					.accessibilityIdentifier(ClaudeConstants.Accessibility.composerField)
					.tutorialAnchor(.claudeComposer)
				VStack(alignment: .trailing, spacing: TestForgeConstants.Spacing.small) {
					Toggle("Screenshot", isOn: $viewModel.attachesScreenshot)
						.toggleStyle(.checkbox)
						.help("Attach the test phone's screen to this message")
						.accessibilityIdentifier(ClaudeConstants.Accessibility.screenshotToggle)
					Button(action: viewModel.send) {
						ActionProgressLabel(
							title: String(localized: "Send"),
							busyTitle: String(localized: "Sending…"),
							isBusy: viewModel.isSending
						)
					}
					.keyboardShortcut(.return, modifiers: .command)
					.disabled(!viewModel.canSend)
					.accessibilityIdentifier(ClaudeConstants.Accessibility.sendButton)
				}
			}
		}
		.padding(TestForgeConstants.Spacing.medium)
	}
}
