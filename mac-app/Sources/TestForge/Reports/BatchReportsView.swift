import SwiftUI

/// Reports › Batches (D-189): every Test Batch on the left; the chosen one's progress, actions and report on the right.
struct BatchReportsView: View {
	@ObservedObject var viewModel: BatchReportsViewModel

	var body: some View {
		HStack(spacing: 0) {
			batchList
				.frame(width: TestForgeConstants.Reports.branchListWidth)
			Divider()
			detailColumn
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.confirmationDialog(removeTitle, isPresented: isRemovalPresented) {
			Button("Remove from list", role: .destructive) {
				viewModel.confirmRemove()
			}
			.accessibilityIdentifier(ReportsConstants.Accessibility.batchRemoveConfirm)
		} message: {
			Text("The proof folder and its report stay on disk.")
		}
		.confirmationDialog(replayTitle, isPresented: isReplayPresented) {
			Button("Replay") {
				viewModel.confirmReplay()
			}
			.accessibilityIdentifier(ReportsConstants.Accessibility.batchReplayConfirm)
		} message: {
			Text("Every recorded case replays on the installed build, driver only, into a new Test Batch. An active batch is ended first, with its report.")
		}
		.alert("Replay started", isPresented: isReplayNoticePresented) {
			Button("OK") {
				viewModel.replayNotice = nil
			}
		} message: {
			Text(viewModel.replayNotice ?? "")
		}
		.alert("Couldn't do that", isPresented: isActionMessagePresented) {
			Button("OK") {
				viewModel.actionMessage = nil
			}
		} message: {
			Text(viewModel.actionMessage ?? "")
		}
	}

	@ViewBuilder
	private var batchList: some View {
		if viewModel.rows.isEmpty {
			ContentUnavailableView(
				"No Test Batches yet",
				systemImage: "archivebox",
				description: Text("Start one from the toolbar; its runs and proof are collected here.")
			)
		} else {
			List(viewModel.rows, selection: $viewModel.selectedBatchId) { row in
				BatchReportRowView(row: row)
					.tag(row.id)
			}
			.accessibilityIdentifier(ReportsConstants.Accessibility.batchList)
			.tutorialAnchor(.batchesList)
		}
	}

	@ViewBuilder
	private var detailColumn: some View {
		if let detail = viewModel.detail {
			VStack(spacing: 0) {
				BatchReportHeaderView(detail: detail, viewModel: viewModel)
				Divider()
				reportContent
			}
			.accessibilityElement(children: .contain)
			.accessibilityIdentifier(ReportsConstants.Accessibility.batchDetail)
		} else {
			ContentUnavailableView("Choose a batch", systemImage: "sidebar.left")
		}
	}

	@ViewBuilder
	private var reportContent: some View {
		switch viewModel.reportState {
			case .noSelection, .loading:
				LoadingStateView(text: "Writing the report…")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .loaded(let blocks):
				MarkdownView(blocks: blocks)
					.accessibilityIdentifier(ReportsConstants.Accessibility.batchReport)
			case .failed(let message):
				ContentUnavailableView {
					Label("No report", systemImage: "doc.text.magnifyingglass")
				} description: {
					Text(message)
				}
		}
	}

	private var removeTitle: Text {
		Text("Remove “\(viewModel.pendingRemoval?.name ?? "")” from the list?")
	}

	private var isRemovalPresented: Binding<Bool> {
		Binding(get: { viewModel.pendingRemoval != nil }, set: { isShown in
			if !isShown {
				viewModel.pendingRemoval = nil
			}
		})
	}

	private var replayTitle: Text {
		Text("Replay “\(viewModel.pendingReplay?.name ?? "")” on this build?")
	}

	private var isReplayPresented: Binding<Bool> {
		Binding(get: { viewModel.pendingReplay != nil }, set: { isShown in
			if !isShown {
				viewModel.pendingReplay = nil
			}
		})
	}

	private var isReplayNoticePresented: Binding<Bool> {
		Binding(get: { viewModel.replayNotice != nil }, set: { isShown in
			if !isShown {
				viewModel.replayNotice = nil
			}
		})
	}

	private var isActionMessagePresented: Binding<Bool> {
		Binding(get: { viewModel.actionMessage != nil }, set: { isShown in
			if !isShown {
				viewModel.actionMessage = nil
			}
		})
	}
}
