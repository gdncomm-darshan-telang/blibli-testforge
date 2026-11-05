import SwiftUI

/// Get Ready › Run queue (D-199): runs on the simulator go one at a time; this is who's first.
struct RunQueueSheetView: View {
	@ObservedObject var viewModel: RunQueueViewModel
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			Text("Run queue")
				.font(.title2.weight(.semibold))
			Label(viewModel.content.deviceText, systemImage: "iphone")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.runQueueDevice)
			list
			if let message = viewModel.message {
				Text(message)
					.font(.caption)
					.foregroundStyle(.red)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.runQueueMessage)
			}
			footer
		}
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(minWidth: TestForgeConstants.GetReady.runQueueWidth, minHeight: TestForgeConstants.GetReady.runQueueHeight, alignment: .topLeading)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.runQueueSheet)
	}

	@ViewBuilder
	private var list: some View {
		if viewModel.content.groups.isEmpty {
			ContentUnavailableView("Nothing queued", systemImage: "tray", description: Text("Replays and Claude runs show here while they wait and run."))
				.accessibilityIdentifier(TestForgeConstants.Accessibility.runQueueEmpty)
		} else {
			List {
				ForEach(viewModel.content.groups) { group in
					Section(group.title) {
						ForEach(group.rows) { row in
							RunQueueRowView(row: row, actionState: viewModel.actionState(forTaskId: row.id)) { action in
								viewModel.perform(action: action, taskId: row.id)
							}
						}
					}
				}
			}
		}
	}

	private var footer: some View {
		HStack {
			if viewModel.content.hasFinished {
				Button {
					viewModel.clearFinished()
				} label: {
					ActionProgressLabel(title: String(localized: "Clear finished"), busyTitle: String(localized: "Clearing…"), isBusy: viewModel.isClearingFinished)
				}
				.disabled(viewModel.isClearingFinished)
				.help("Removes finished runs from this list; their results stay in Reports")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.runQueueClearFinished)
			}
			Spacer()
			Button("Done") {
				dismiss()
			}
			.keyboardShortcut(.defaultAction)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.runQueueDone)
		}
	}
}
