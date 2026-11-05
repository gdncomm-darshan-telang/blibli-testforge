import SwiftUI

/// Reports › Demos (D-177): recorded demos on the left with a play button, the playing one on the right.
struct DemoLibraryView: View {
	@ObservedObject var viewModel: DemoLibraryViewModel

	var body: some View {
		HSplitView {
			listColumn
				.frame(
					minWidth: DemoLibraryConstants.listMinWidth,
					idealWidth: DemoLibraryConstants.listIdealWidth,
					maxWidth: DemoLibraryConstants.listMaxWidth,
					maxHeight: .infinity
				)
			playerColumn
				.frame(minWidth: DemoLibraryConstants.playerMinWidth, maxWidth: .infinity, maxHeight: .infinity)
		}
		.onAppear(perform: viewModel.load)
		.onDisappear(perform: viewModel.pause)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(DemoLibraryConstants.Accessibility.library)
	}

	@ViewBuilder
	private var listColumn: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Recorded demos")
					.font(.headline)
				Spacer()
				if viewModel.isRefreshing {
					HStack(spacing: TestForgeConstants.Spacing.small) {
						ProgressView()
							.controlSize(.small)
						Text("Refreshing…")
							.font(.callout)
							.foregroundStyle(.secondary)
					}
					.accessibilityElement(children: .combine)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.demoLibraryRefreshProgress)
				}
				Button(action: viewModel.load) {
					Label("Refresh", systemImage: "arrow.clockwise")
				}
				.labelStyle(.iconOnly)
				.disabled(viewModel.isRefreshing)
				.help("Look for new demos")
				.accessibilityIdentifier(DemoLibraryConstants.Accessibility.refresh)
			}
			.padding(TestForgeConstants.Spacing.medium)
			Divider()
			listContent
		}
	}

	@ViewBuilder
	private var listContent: some View {
		switch viewModel.state {
			case .loading:
				ProgressView()
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .empty:
				EmptyStateView(content: Self.noDemosContent)
			case .failed(let message):
				Text(message)
					.foregroundStyle(.secondary)
					.padding()
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.accessibilityIdentifier(DemoLibraryConstants.Accessibility.failed)
			case .loaded(let recordings):
				List(recordings, selection: $viewModel.selectedId) { recording in
					DemoRecordingRowView(recording: recording, isSelected: recording.id == viewModel.selectedId)
						.tag(recording.id)
				}
				.accessibilityIdentifier(DemoLibraryConstants.Accessibility.list)
				.tutorialAnchor(.demoLibrary)
		}
	}

	@ViewBuilder
	private var playerColumn: some View {
		if viewModel.player == nil {
			EmptyStateView(content: Self.nothingPlayingContent)
		} else {
			DemoPlayerPaneView(viewModel: viewModel)
		}
	}

	private static let noDemosContent = EmptyStateContent(
		title: "No demos yet",
		systemImage: "film",
		message: "In Tests, pick a recorded case and choose Explain › Record demo video. It shows here in English and Bahasa."
	)

	private static let nothingPlayingContent = EmptyStateContent(
		title: "Pick a demo",
		systemImage: "play.rectangle",
		message: "Click a demo to open it here, then press ▶ when you are ready. Choose English or Bahasa Indonesia above the video."
	)
}
