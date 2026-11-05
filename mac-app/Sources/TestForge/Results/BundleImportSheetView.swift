import SwiftUI

/// Preview → import → replay, one sheet; nothing is written until Import.
struct BundleImportSheetView: View {
	@ObservedObject var viewModel: BundleImportViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			Text("Import a run bundle")
				.font(.title2.weight(.semibold))
			content
		}
		.padding(TestForgeConstants.Spacing.large)
		.frame(width: TestForgeConstants.Results.bundleSheetWidth, alignment: .leading)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsBundleSheet)
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.state {
			case .idle:
				EmptyView()
			case .inspecting:
				LoadingStateView(text: "Reading the bundle…")
			case .importing:
				LoadingStateView(text: "Adding its macros, elements and mocks…")
			case .replaying:
				LoadingStateView(text: "Starting the replay…")
			case .preview(let model):
				BundleImportSummaryView(model: model)
				mockList(model: model)
				previewButtons(model: model)
			case .imported(let model):
				BundleImportSummaryView(model: model)
				mockList(model: model)
				importedButtons(model: model)
			case .failed(let message):
				Label(message, systemImage: "exclamationmark.triangle.fill")
					.foregroundStyle(.orange)
				closeRow
		}
	}

	@ViewBuilder
	private func mockList(model: BundleImportModel) -> some View {
		if !model.mockRows.isEmpty {
			BundleCaseMockListView(rows: model.mockRows, armMessage: viewModel.armMessage) { caseId in
				viewModel.armMocks(caseId: caseId)
			}
		}
	}

	private func previewButtons(model: BundleImportModel) -> some View {
		HStack {
			Spacer()
			Button("Cancel", role: .cancel) {
				viewModel.close()
			}
			.keyboardShortcut(.cancelAction)
			if model.conflictText != nil {
				Button("Replace mine and import") {
					viewModel.importBundle(replacesDiffering: true)
				}
				.help("Use the bundle's macros, elements and mocks where they differ from yours")
			}
			Button("Import") {
				viewModel.importBundle(replacesDiffering: false)
			}
			.keyboardShortcut(.defaultAction)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsBundleImportButton)
		}
	}

	private func importedButtons(model: BundleImportModel) -> some View {
		HStack {
			Text("Its cases are loaded on Test Cases.")
				.font(.callout)
				.foregroundStyle(.secondary)
			Spacer()
			Button("Close", role: .cancel) {
				viewModel.close()
			}
			.keyboardShortcut(.cancelAction)
			Button(model.replayButtonTitle) {
				viewModel.replay()
			}
			.keyboardShortcut(.defaultAction)
			.disabled(!model.canReplay)
			.help("Driver only: a case that fails is reported, never sent to Claude")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsBundleReplayButton)
		}
	}

	private var closeRow: some View {
		HStack {
			Spacer()
			Button("Close", role: .cancel) {
				viewModel.close()
			}
			.keyboardShortcut(.cancelAction)
		}
	}
}
