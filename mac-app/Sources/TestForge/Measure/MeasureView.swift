import SwiftUI

/// The Measure window: a capture of the simulator with every element's frame; click one for its size and spacing.
struct MeasureView: View {
	@ObservedObject var viewModel: MeasureViewModel
	@EnvironmentObject private var tutorials: TutorialCoordinator

	var body: some View {
		content
			.frame(minWidth: TestForgeConstants.Measure.windowMinWidth, minHeight: TestForgeConstants.Measure.windowMinHeight)
			.toolbar {
				ToolbarItem(placement: .principal) {
					MeasureZoomBarView(viewModel: viewModel)
				}
				ToolbarItem(placement: .automatic) {
					MeasureLayerBorderControlsView(viewModel: viewModel)
				}
				ToolbarItem(placement: .primaryAction) {
					Button(action: viewModel.startSnapshot) {
						Label("Snapshot with notes", systemImage: "camera.viewfinder")
					}
					.disabled(viewModel.selection == nil)
					.help("Snapshot the selected view with its spacing, add numbered notes, then save or copy the image")
					.accessibilityIdentifier(TestForgeConstants.Accessibility.measureSnapshotButton)
					.tutorialAnchor(.measureSnapshotButton)
				}
				ToolbarItem(placement: .primaryAction) {
					Button {
						viewModel.refresh()
					} label: {
						Label("Capture again", systemImage: "arrow.clockwise")
					}
					.help("Capture the simulator screen and its elements again (⌘R)")
					.keyboardShortcut("r")
					.accessibilityIdentifier(TestForgeConstants.Accessibility.measureRefreshButton)
					.tutorialAnchor(.measureRefreshButton)
				}
				ToolbarItem(placement: .primaryAction) {
					TutorialHelpMenuView(features: [.measure]) { feature in
						tutorials.start(feature)
					}
				}
			}
			.navigationTitle(Text("Measure"))
			.sheet(item: $viewModel.snapshotSession) { session in
				MeasureSnapshotSheetView(viewModel: session)
			}
			.onAppear {
				viewModel.refresh()
			}
			.onChange(of: viewModel.state) {
				if case .loaded = viewModel.state {
					tutorials.autoStart(.measure)
				}
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.measure)
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.state {
			case .idle, .loading:
				LoadingStateView(text: "Reading the simulator screen…")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .loaded(let snapshot):
				HSplitView {
					MeasureCanvasView(content: canvasContent(snapshot: snapshot), zoom: $viewModel.zoom, actions: canvasActions)
						.frame(minWidth: TestForgeConstants.Measure.canvasMinWidth, maxWidth: .infinity, maxHeight: .infinity)
						.overlay(alignment: .bottom) {
							if viewModel.layerPass != .idle {
								MeasureLayerPassBannerView(state: viewModel.layerPass)
							}
						}
					MeasureDetailView(content: detailContent(snapshot: snapshot)) {
						viewModel.copyDetails()
					}
					.frame(width: TestForgeConstants.Measure.detailWidth)
				}
			case .failed(let message):
				EmptyStateView(content: failureContent(message: message)) {
					Button("Try again") {
						viewModel.refresh()
					}
				}
		}
	}

	private func canvasContent(snapshot: MeasureSnapshot) -> MeasureCanvasContent {
		MeasureCanvasContent(
			snapshot: snapshot,
			selection: viewModel.selection,
			hovered: viewModel.hovered,
			unidentifiedBorder: viewModel.showsUnidentifiedBorders ? viewModel.unidentifiedBorderColor : nil
		)
	}

	private func detailContent(snapshot: MeasureSnapshot) -> MeasureDetailContent {
		MeasureDetailContent(
			snapshot: snapshot,
			selection: viewModel.selection,
			hovered: viewModel.hovered
		)
	}

	private var canvasActions: MeasureCanvasActions {
		let measureViewModel = viewModel
		return MeasureCanvasActions(
			selectPoint: { devicePoint in measureViewModel.select(at: devicePoint) },
			selectElement: { elementId in measureViewModel.select(elementId: elementId) },
			hoverPoint: { devicePoint in measureViewModel.hover(at: devicePoint) }
		)
	}

	private func failureContent(message: String) -> EmptyStateContent {
		EmptyStateContent(title: "Couldn't measure this screen", systemImage: "ruler", message: "\(message)")
	}
}
