import SwiftUI

/// Board C9: runs on the left, the selected run's cases in the middle, the selected case's proof on the right.
struct ResultsSectionView: View {
	@ObservedObject var viewModel: ResultsSectionViewModel
	@ObservedObject var bundleImport: BundleImportViewModel
	let proofViewer: ProofViewerViewModel
	@Environment(\.openWindow) private var openWindow

	var body: some View {
		HStack(spacing: 0) {
			runListColumn
				.frame(width: TestForgeConstants.Results.runListWidth)
			Divider()
			detailColumn
				.frame(minWidth: TestForgeConstants.Results.detailMinWidth, maxWidth: .infinity, maxHeight: .infinity)
			if let caseDetail = viewModel.caseDetail {
				Divider()
				inspector(caseDetail: caseDetail)
					.frame(width: TestForgeConstants.Results.inspectorWidth)
			}
		}
		.accessibilityElement(children: .contain)
		.sheet(isPresented: isBundleSheetPresented) {
			BundleImportSheetView(viewModel: viewModel.bundleImportViewModel)
		}
		.sheet(item: $viewModel.pendingOverride) { draft in
			let model = viewModel.overrideSheet ?? OverrideVerdictSheetModel(caseId: draft.caseId, isSaving: false, failure: nil)
			OverrideVerdictSheetView(model: model) { verdict, reason in
				viewModel.saveOverride(verdict: verdict, reason: reason)
			} onCancel: {
				viewModel.cancelOverride()
			}
			.interactiveDismissDisabled(model.isSaving)
		}
		.confirmationDialog(rerunTitle, isPresented: $viewModel.isRerunConfirmationPresented) {
			Button("Re-run failed cases") {
				viewModel.confirmRerunFailed()
			}
			Button("Cancel", role: .cancel) {
				viewModel.isRerunConfirmationPresented = false
			}
		} message: {
			Text("Recorded cases replay without Claude. Cases with no recording run through Claude and use your plan.")
		}
		.alert(actionFailedTitle, isPresented: isActionMessagePresented) {
			Button("OK") {
				viewModel.dismissMessage()
			}
		} message: {
			Text(viewModel.actionMessage ?? "")
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.results)
	}

	private var runListColumn: some View {
		VStack(spacing: 0) {
			ResultImportBundleBarView {
				viewModel.bundleImportViewModel.chooseBundle()
			}
			Divider()
			runList
		}
	}

	@ViewBuilder
	private var runList: some View {
		switch viewModel.listState {
			case .empty:
				EmptyStateView(content: Self.noRunsContent)
			case .loaded(let rows):
				ResultRunListView(rows: rows, selection: $viewModel.selectedRunId)
		}
	}

	@ViewBuilder
	private var detailColumn: some View {
		switch viewModel.detailState {
			case .noSelection:
				EmptyStateView(content: Self.noSelectionContent)
			case .loading:
				LoadingStateView(text: "Loading the run…")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .failed(let message):
				EmptyStateView(content: Self.loadFailedContent) {
					Text(message)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			case .loaded(let detail):
				let actions = ResultRunActions(
					rerunFailed: { viewModel.isRerunConfirmationPresented = true },
					exportReport: { viewModel.exportReport() },
					copyReport: { viewModel.copyReport() },
					exportBundle: { viewModel.exportBundle() },
					showProofInFinder: { url in viewModel.showProofInFinder(url: url) }
				)
				let controls = ResultRunControls(actions: actions, feedback: viewModel.feedback)
				ResultRunDetailView(detail: detail, controls: controls, selection: $viewModel.selectedCaseIndex)
		}
	}

	private func inspector(caseDetail: ResultCaseDetailModel) -> some View {
		let actions = ResultReviewActions(
			accept: { viewModel.acceptSelectedCase() },
			override: { viewModel.requestOverride() },
			markForRerun: { viewModel.markSelectedCaseForRerun() }
		)
		let proofActions = ResultProofActions(
			openFile: { url in openProofViewer(caseDetail: caseDetail, url: url) },
			showInFinder: { url in viewModel.showProofInFinder(url: url) }
		)
		let controls = ResultReviewControls(actions: actions, feedback: viewModel.feedback)
		return ResultCaseInspectorView(detail: caseDetail, reviewControls: controls, proofActions: proofActions)
	}

	private func openProofViewer(caseDetail: ResultCaseDetailModel, url: URL) {
		let request = caseDetail.proofViewerRequest(selecting: url)
		proofViewer.show(request: request)
		openWindow(id: TestForgeConstants.Window.proofViewerWindowId)
	}

	private static let noRunsContent = EmptyStateContent(
		title: "No runs yet",
		systemImage: "checkmark.seal",
		message: "Runs started from a batch or Run again are kept here with their proof."
	)

	private static let noSelectionContent = EmptyStateContent(
		title: "Select a run",
		systemImage: "list.bullet.rectangle",
		message: "Its cases, verdicts and review show here."
	)

	private static let loadFailedContent = EmptyStateContent(
		title: "The run didn't load",
		systemImage: "exclamationmark.triangle",
		message: "Select it again, or check the server in Get ready."
	)

	private var rerunTitle: Text {
		Text("Re-run the failed cases?")
	}

	private var actionFailedTitle: Text {
		Text("That didn't work")
	}

	private var isBundleSheetPresented: Binding<Bool> {
		Binding {
			bundleImport.isSheetPresented
		} set: { isPresented in
			if !isPresented {
				bundleImport.close()
			}
		}
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
