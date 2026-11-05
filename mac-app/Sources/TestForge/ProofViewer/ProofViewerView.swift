import SwiftUI

/// The Proof window: the selected screenshot or video, its controls, and the case's other proof in a strip below.
struct ProofViewerView: View {
	@ObservedObject var viewModel: ProofViewerViewModel

	var body: some View {
		VStack(spacing: 0) {
			mediaContent
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			if viewModel.items.count > 1 {
				Divider()
				ProofThumbnailStripView(items: viewModel.items, selectedIndex: viewModel.selectedIndex) { index in
					viewModel.select(index: index)
				}
			}
		}
		.navigationTitle(viewModel.title)
		.navigationSubtitle(subtitle)
		.toolbar {
			ToolbarItemGroup(placement: .navigation) {
				navigationButtons
			}
			ToolbarItemGroup(placement: .primaryAction) {
				fileButtons
			}
		}
		.onDisappear {
			viewModel.windowDidClose()
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewer)
	}

	@ViewBuilder
	private var mediaContent: some View {
		switch viewModel.selectedItem?.kind {
			case .image:
				ProofImageView(viewModel: viewModel.imageViewModel)
			case .video:
				ProofVideoView(viewModel: viewModel.videoViewModel)
			case nil:
				ContentUnavailableView("No proof selected", systemImage: "photo.on.rectangle", description: Text("Click a screenshot or video in Results."))
		}
	}

	@ViewBuilder
	private var navigationButtons: some View {
		Button(action: viewModel.showPrevious) {
			Label("Previous", systemImage: "chevron.left")
		}
		.keyboardShortcut(.leftArrow, modifiers: [])
		.disabled(!viewModel.canShowPrevious)
		.help("Previous proof file (←)")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerPrevious)
		Button(action: viewModel.showNext) {
			Label("Next", systemImage: "chevron.right")
		}
		.keyboardShortcut(.rightArrow, modifiers: [])
		.disabled(!viewModel.canShowNext)
		.help("Next proof file (→)")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerNext)
	}

	@ViewBuilder
	private var fileButtons: some View {
		Button(action: viewModel.openInDefaultApp) {
			Label("Open in Default App", systemImage: "arrow.up.forward.app")
		}
		.disabled(viewModel.selectedItem == nil)
		.help("Open in Preview or QuickTime Player")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerOpenExternally)
		Button(action: viewModel.showInFinder) {
			Label("Show in Finder", systemImage: "folder")
		}
		.disabled(viewModel.selectedItem == nil)
		.help("Show this file in Finder")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerShowInFinder)
	}

	private var subtitle: String {
		guard let item = viewModel.selectedItem else {
			return ""
		}
		return "\(item.name) · \(viewModel.positionText)"
	}
}
