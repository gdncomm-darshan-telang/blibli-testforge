import SwiftUI

/// Tests › Run all (D-191): the batch's plan and anything that would stop it, before it starts.
struct BatchPlanSheetView: View {
	@ObservedObject var viewModel: BatchPlanViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			content
		}
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(width: TestForgeConstants.GetReady.prerequisitesWidth)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.batchPlanSheet)
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.state {
			case .hidden, .loading:
				LoadingStateView(text: "Planning the batch…")
					.frame(maxWidth: .infinity)
				cancelRow(canStart: false)
			case .failed(let message):
				Label(message, systemImage: "exclamationmark.triangle")
					.foregroundStyle(.red)
				cancelRow(canStart: false)
			case .ready(let sheet):
				Text(sheet.title)
					.font(.title3.weight(.semibold))
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
					ForEach(sheet.lines, id: \.self) { line in
						Label(line, systemImage: "checkmark.circle")
					}
					ForEach(sheet.stops) { stop in
						Label(stop.text, systemImage: "hand.raised")
							.foregroundStyle(.orange)
							.accessibilityIdentifier(TestForgeConstants.Accessibility.batchPlanStopPrefix + stop.id)
					}
				}
				.font(.callout)
				.fixedSize(horizontal: false, vertical: true)
				if let failureMessage = viewModel.startFailureMessage {
					Label(failureMessage, systemImage: "exclamationmark.triangle")
						.foregroundStyle(.red)
						.fixedSize(horizontal: false, vertical: true)
						.textSelection(.enabled)
						.accessibilityIdentifier(TestForgeConstants.Accessibility.batchPlanStartFailure)
				}
				cancelRow(canStart: true)
		}
	}

	private func cancelRow(canStart: Bool) -> some View {
		HStack {
			Spacer()
			Button("Cancel", role: .cancel) {
				viewModel.dismiss()
			}
			.keyboardShortcut(.cancelAction)
			.disabled(viewModel.isStarting)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.batchPlanCancel)
			Button {
				viewModel.start()
			} label: {
				ActionProgressLabel(title: String(localized: "Start"), busyTitle: String(localized: "Starting…"), isBusy: viewModel.isStarting)
			}
			.keyboardShortcut(.defaultAction)
			.disabled(!canStart || viewModel.isStarting)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.batchPlanStart)
		}
	}
}
