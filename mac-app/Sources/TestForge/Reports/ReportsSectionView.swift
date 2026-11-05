import SwiftUI

/// Reports: the session report (D-176), recorded demos (D-177) or, per branch, runs, their comparison and report (board C10).
struct ReportsSectionView: View {
	@ObservedObject var viewModel: ReportsSectionViewModel
	let sessionReport: SessionReportViewModel
	let demoLibrary: DemoLibraryViewModel
	let batchReports: BatchReportsViewModel
	@ObservedObject var navigator: ReportsNavigator

	var body: some View {
		VStack(spacing: 0) {
			Picker("Report", selection: $navigator.mode) {
				ForEach(ReportsMode.allCases) { reportMode in
					Text(reportMode.title).tag(reportMode)
				}
			}
			.pickerStyle(.segmented)
			.labelsHidden()
			.fixedSize()
			.padding(TestForgeConstants.Spacing.medium)
			.accessibilityIdentifier(ReportsConstants.Accessibility.modePicker)
			Divider()
			switch navigator.mode {
				case .session:
					SessionReportView(viewModel: sessionReport)
				case .batches:
					BatchReportsView(viewModel: batchReports)
				case .runs:
					runsContent
				case .demos:
					DemoLibraryView(viewModel: demoLibrary)
			}
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.reports)
	}

	/// Board C10: branches on the left; the chosen run, its comparison and its report on the right.
	private var runsContent: some View {
		HStack(spacing: 0) {
			branchColumn
				.frame(width: TestForgeConstants.Reports.branchListWidth)
			Divider()
			reportColumn
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.accessibilityElement(children: .contain)
		.confirmationDialog(publishTitle, isPresented: $viewModel.isPublishConfirmationPresented) {
			Button("Publish with Claude") {
				viewModel.confirmPublish()
			}
			Button("Cancel", role: .cancel) {
				viewModel.isPublishConfirmationPresented = false
			}
		} message: {
			Text(Self.publishMessage)
		}
		.alert(actionFailedTitle, isPresented: isActionMessagePresented) {
			Button("OK") {
				viewModel.dismissMessage()
			}
		} message: {
			Text(viewModel.actionMessage ?? "")
		}
	}

	@ViewBuilder
	private var branchColumn: some View {
		switch viewModel.listState {
			case .empty:
				EmptyStateView(content: Self.noHistoryContent)
			case .loaded(let rows):
				BranchHistoryListView(rows: rows, selection: $viewModel.selectedBranch)
		}
	}

	@ViewBuilder
	private var reportColumn: some View {
		if let preview = viewModel.preview {
			ScrollView {
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.extraLarge) {
					ReportPickerBarView(
						runOptions: viewModel.runOptions,
						baseOptions: viewModel.baseOptions,
						selectedRunId: $viewModel.selectedRunId,
						selectedBaseRunId: $viewModel.selectedBaseRunId
					)
					RunComparisonView(state: viewModel.comparisonState)
					reportPreview(preview: preview)
				}
				.padding(TestForgeConstants.Spacing.extraLarge)
				.frame(maxWidth: TestForgeConstants.Reports.contentMaxWidth, alignment: .leading)
				.frame(maxWidth: .infinity, alignment: .leading)
			}
		} else {
			EmptyStateView(content: Self.noSelectionContent)
		}
	}

	private func reportPreview(preview: ReportPreviewModel) -> some View {
		let actions = ReportPreviewActions(
			exportReport: { viewModel.exportReport() },
			copyReport: { viewModel.copyReport() },
			publish: { viewModel.isPublishConfirmationPresented = true }
		)
		return ReportPreviewView(preview: preview, feedback: viewModel.previewFeedback, actions: actions)
	}

	private static let noHistoryContent = EmptyStateContent(
		title: "No history yet",
		systemImage: "clock.arrow.circlepath",
		message: "Every run is kept with its branch, commit, phone and server."
	)

	private static let noSelectionContent = EmptyStateContent(
		title: "Select a branch",
		systemImage: "doc.richtext",
		message: "Its newest run, what changed and the report show here."
	)

	private static let publishMessage: LocalizedStringKey = """
		Claude creates one new page under your personal Confluence page. \
		The production test-case page is never written to. This uses your Claude plan.
		"""

	private var publishTitle: Text {
		Text("Publish this report to Confluence?")
	}

	private var actionFailedTitle: Text {
		Text("That didn't work")
	}

	private var isActionMessagePresented: Binding<Bool> {
		Binding {
			viewModel.actionMessage != nil
		} set: { isPresented in
			if !isPresented {
				viewModel.dismissMessage()
			}
		}
	}
}
