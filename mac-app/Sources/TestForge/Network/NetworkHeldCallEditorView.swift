import SwiftUI

/// The selected held call: change the status or body, then Continue — or Fail it as offline, timed out or dropped.
struct NetworkHeldCallEditorView<ViewModel: NetworkBreakpointsPresenting>: View {
	@ObservedObject var viewModel: ViewModel
	let held: HeldCallModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Text(held.endpoint)
				.font(.headline.monospaced())
				.textSelection(.enabled)
			Text(held.detailText)
				.font(.caption)
				.foregroundStyle(.secondary)
				.textSelection(.enabled)
			if held.isResponse {
				HStack(spacing: TestForgeConstants.Spacing.medium) {
					Text("Status")
					TextField("200", text: $viewModel.editedStatusText)
						.textFieldStyle(.roundedBorder)
						.frame(width: NetworkConsoleConstants.Editor.numberFieldWidth)
						.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.heldStatusField)
				}
			}
			TextEditor(text: $viewModel.editedBody)
				.font(.callout.monospaced())
				.border(.quaternary)
				.disabled(!held.canEditBody)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.heldBodyEditor)
			footer
		}
		.padding(TestForgeConstants.Spacing.medium)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.heldEditor)
	}

	@ViewBuilder
	private var footer: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Picker("Fail as", selection: $viewModel.failure) {
				ForEach(NetworkFailureKind.allCases) { failure in
					Text(failure.title).tag(failure)
				}
			}
			.fixedSize()
			.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.heldFailurePicker)
			Button("Fail", systemImage: "bolt.slash", role: .destructive, action: viewModel.failSelected)
				.disabled(viewModel.isWorking)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.heldFailButton)
			Spacer()
			if viewModel.isWorking {
				ProgressView()
					.controlSize(.small)
			}
			Button("Continue", systemImage: "play.fill", action: viewModel.continueSelected)
				.keyboardShortcut(.defaultAction)
				.disabled(viewModel.isWorking)
				.help("Let it go on, with your edits")
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.heldContinueButton)
		}
	}
}
