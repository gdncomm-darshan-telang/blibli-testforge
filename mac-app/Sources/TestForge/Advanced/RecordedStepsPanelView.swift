import SwiftUI

/// Recorded steps: every saved macro, searchable, with its steps and a Replay button.
struct RecordedStepsPanelView: View {
	@ObservedObject var viewModel: RecordedStepsViewModel

	var body: some View {
		HStack(spacing: 0) {
			VStack(spacing: 0) {
				searchBar
				Divider()
				listContent
			}
			.frame(width: TestForgeConstants.Advanced.macroListWidth)
			Divider()
			MacroDetailView(detail: viewModel.detail, replay: viewModel.replayFeedback) {
				viewModel.replaySelected()
			}
		}
		.onAppear {
			viewModel.loadIfNeeded()
		}
		.alert("That didn't work", isPresented: isMessagePresented) {
			Button("OK") {
				viewModel.dismissMessage()
			}
		} message: {
			Text(viewModel.actionMessage ?? "")
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.recordedSteps)
	}

	private var searchBar: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack {
				TextField("Search by name, id or test case", text: $viewModel.searchText)
					.textFieldStyle(.roundedBorder)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.recordedStepsSearch)
				Button {
					viewModel.reload()
				} label: {
					Label("Reload", systemImage: "arrow.clockwise")
				}
				.labelStyle(.iconOnly)
				.help("Read the recordings again")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.recordedStepsReloadButton)
			}
			if let lintSummary = viewModel.lintSummary {
				Text(lintSummary)
					.font(.caption)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.recordedStepsLint)
			}
		}
		.padding(TestForgeConstants.Spacing.medium)
	}

	@ViewBuilder
	private var listContent: some View {
		switch viewModel.state {
			case .notLoaded, .loading:
				ProgressView()
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .loaded(let rows):
				List(rows, selection: $viewModel.selectedMacroId) { row in
					MacroRowView(row: row)
						.tag(row.id)
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.recordedStepsList)
				.tutorialAnchor(.recordedStepsList)
			case .failed(let message):
				EmptyStateView(content: EmptyStateContent(
					title: "Couldn't read the recordings",
					systemImage: "exclamationmark.triangle",
					message: "\(message)"
				))
		}
	}

	private var isMessagePresented: Binding<Bool> {
		Binding {
			viewModel.actionMessage != nil
		} set: { isPresented in
			if !isPresented {
				viewModel.dismissMessage()
			}
		}
	}
}
