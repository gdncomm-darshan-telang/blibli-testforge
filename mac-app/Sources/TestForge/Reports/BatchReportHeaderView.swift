import SwiftUI

struct BatchReportHeaderView: View {
	let detail: BatchReportDetailModel
	@ObservedObject var viewModel: BatchReportsViewModel

	var body: some View {
		HStack(alignment: .top, spacing: TestForgeConstants.Spacing.medium) {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(detail.name)
					.font(.title3.weight(.semibold))
				Text(detail.statusText)
					.font(.callout)
					.foregroundStyle(.secondary)
				Text(detail.progressText)
					.font(.callout)
					.accessibilityIdentifier(ReportsConstants.Accessibility.batchProgress)
					.tutorialAnchor(.batchesProgress)
				if let comparisonText = detail.comparisonText {
					Label(comparisonText, systemImage: detail.hasRegressions ? "exclamationmark.triangle.fill" : "arrow.left.arrow.right")
						.font(.callout)
						.foregroundStyle(detail.hasRegressions ? .orange : .secondary)
						.accessibilityIdentifier(ReportsConstants.Accessibility.batchComparison)
				}
			}
			Spacer()
			actionButtons
		}
		.padding(TestForgeConstants.Spacing.medium)
	}

	@ViewBuilder
	private var actionButtons: some View {
		Button {
			viewModel.reloadReport()
		} label: {
			progressLabel(action: .refresh)
		}
		.disabled(viewModel.isBusy)
		.help("Write the report again from the batch's work so far")
		.accessibilityIdentifier(ReportsConstants.Accessibility.batchRefresh)
		Button("Show in Finder", systemImage: "folder") {
			viewModel.revealSelected()
		}
		.help("Open the batch's proof folder")
		.accessibilityIdentifier(ReportsConstants.Accessibility.batchReveal)
		switch detail.status {
			case .active:
				Button {
					viewModel.pauseSelected()
				} label: {
					progressLabel(action: .pause)
				}
				.disabled(viewModel.isBusy)
				.help("Set this batch aside to work on something else; nothing joins it until you resume it")
				.accessibilityIdentifier(ReportsConstants.Accessibility.batchPause)
				.tutorialAnchor(.batchesPause)
				endButton
			case .paused:
				Button {
					viewModel.resumeSelected()
				} label: {
					progressLabel(action: .resume)
				}
				.disabled(viewModel.isBusy)
				.help("Make this batch active again; the active batch is paused in its place")
				.accessibilityIdentifier(ReportsConstants.Accessibility.batchResume)
				.tutorialAnchor(.batchesPause)
				endButton
			case .ended:
				endedButtons
		}
	}

	private var endButton: some View {
		Button {
			viewModel.endSelected()
		} label: {
			progressLabel(action: .end)
		}
		.disabled(viewModel.isBusy)
		.help("End the batch and write its report into its folder")
		.accessibilityIdentifier(ReportsConstants.Accessibility.batchEnd)
	}

	@ViewBuilder
	private var endedButtons: some View {
		Button {
			viewModel.reopenSelected()
		} label: {
			progressLabel(action: .reopen)
		}
		.disabled(viewModel.isBusy)
		.help("Make this batch active again; new work and proof join it. An active batch is paused first.")
		.accessibilityIdentifier(ReportsConstants.Accessibility.batchReopen)
		.tutorialAnchor(.batchesReopen)
		Button {
			viewModel.requestReplaySelected()
		} label: {
			progressLabel(action: .replay)
		}
		.disabled(!detail.canReplay || viewModel.isBusy)
		.help("Regression check: replay every recorded case of this batch on the app installed now, no Claude, into a new batch compared case by case")
		.accessibilityIdentifier(ReportsConstants.Accessibility.batchReplay)
		.tutorialAnchor(.batchesReplay)
		Button {
			viewModel.requestRemoveSelected()
		} label: {
			progressLabel(action: .remove)
		}
		.disabled(viewModel.isBusy)
		.help("Take it off this list; the proof folder and report stay on disk")
		.accessibilityIdentifier(ReportsConstants.Accessibility.batchRemove)
	}

	@ViewBuilder
	private func progressLabel(action: BatchReportAction) -> some View {
		let text = BatchReportActionLabelText(action: action)
		if viewModel.isRunning(action) {
			ActionProgressLabel(title: text.title, busyTitle: text.busyTitle, isBusy: true)
		} else {
			Label(text.title, systemImage: text.systemImage)
		}
	}
}
