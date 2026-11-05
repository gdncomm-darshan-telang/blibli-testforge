import SwiftUI

/// Names a new Test Batch; everything run until it ends lands in its own proof subfolder.
struct TestBatchStartSheetView<ViewModel: TestBatchPresenting>: View {
	@ObservedObject var viewModel: ViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			Text("Start a Test Batch")
				.font(.title2.weight(.semibold))
			Text("Name it after a ticket, build or feature. Every run, replay, Claude run and scan is collected in it until you end it.")
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
			if let startNote = viewModel.startNote {
				Label(startNote, systemImage: "pause.circle")
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchStartNote)
			}
			TextField("e.g. IOS-46102 flash sale schedule", text: $viewModel.draftName)
				.textFieldStyle(.roundedBorder)
				.onSubmit(viewModel.confirmStart)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchNameField)
			if viewModel.startNote == nil, !viewModel.pausedBatches.isEmpty {
				TestBatchPausedListView(batches: viewModel.pausedBatches, actionState: viewModel.actionState) { batch in
					viewModel.resume(batch: batch)
				}
			}
			if let failureMessage = viewModel.failureMessage {
				Label(failureMessage, systemImage: "exclamationmark.triangle")
					.foregroundStyle(.red)
					.fixedSize(horizontal: false, vertical: true)
					.textSelection(.enabled)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchStartFailure)
			}
			HStack {
				Spacer()
				Button("Cancel", role: .cancel, action: viewModel.cancelStart)
					.keyboardShortcut(.cancelAction)
					.disabled(viewModel.isWorking)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchCancelButton)
				Button(action: viewModel.confirmStart) {
					ActionProgressLabel(
						title: String(localized: "Start"),
						busyTitle: String(localized: "Starting…"),
						isBusy: viewModel.isRunning(.start)
					)
				}
				.keyboardShortcut(.defaultAction)
				.disabled(!viewModel.canStart)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchStartButton)
			}
		}
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(width: TestForgeConstants.TestBatch.sheetWidth)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchStartSheet)
	}
}
