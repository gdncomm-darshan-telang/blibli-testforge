import SwiftUI

/// The run is waiting for you (D-044/D-199): tap a system popup by hand or type a real OTP, then the run carries on.
struct RunPromptSheetView: View {
	@ObservedObject var viewModel: RunPromptViewModel
	let prompt: RunPrompt

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			Text("The run is waiting for you")
				.font(.caption.weight(.semibold))
				.foregroundStyle(.orange)
			Text(prompt.title)
				.font(.title2.weight(.semibold))
			Text(prompt.text)
				.fixedSize(horizontal: false, vertical: true)
				.textSelection(.enabled)
			if prompt.kind == .input {
				input
			}
			if let message = viewModel.message {
				Text(message)
					.font(.caption)
					.foregroundStyle(.red)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.runPromptMessage)
			}
			actions
		}
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(width: TestForgeConstants.GetReady.runPromptWidth)
		.interactiveDismissDisabled()
		.accessibilityIdentifier(TestForgeConstants.Accessibility.runPromptSheet)
	}

	@ViewBuilder
	private var input: some View {
		if prompt.isSecret {
			SecureField("Value", text: $viewModel.value)
				.textFieldStyle(.roundedBorder)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.runPromptInput)
		} else {
			TextField("Value", text: $viewModel.value)
				.textFieldStyle(.roundedBorder)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.runPromptInput)
		}
	}

	private var actions: some View {
		HStack {
			Button("Stop the run", role: .destructive) {
				viewModel.send(answer: .stop)
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.runPromptStop)
			Button("Show Simulator") {
				viewModel.showSimulator()
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.runPromptShowSimulator)
			Spacer()
			Button(viewModel.skipTitle) {
				viewModel.send(answer: .skip)
			}
			.help("The app never showed it — carry on")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.runPromptSkip)
			Button(viewModel.doneTitle) {
				viewModel.send(answer: .done)
			}
			.keyboardShortcut(.defaultAction)
			.disabled(!viewModel.canSendDone)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.runPromptDone)
		}
		.disabled(viewModel.isSending)
	}
}
