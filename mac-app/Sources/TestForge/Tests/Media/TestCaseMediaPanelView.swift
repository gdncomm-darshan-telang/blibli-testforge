import SwiftUI

/// D-183: the case's proof under its detail — screenshots zoom, pan and take annotations; videos play.
struct TestCaseMediaPanelView: View {
	@ObservedObject var viewModel: TestCaseMediaViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			headerRow
			Divider()
			content
				.frame(maxWidth: .infinity)
				.frame(height: TestForgeConstants.Tests.mediaViewerHeight)
			if viewModel.items.count > 1 {
				Divider()
				ProofThumbnailStripView(items: viewModel.items, selectedIndex: viewModel.selectedIndex) { index in
					viewModel.select(index: index)
				}
				.disabled(viewModel.isAnnotating)
			}
		}
		.background(.background.secondary, in: RoundedRectangle(cornerRadius: TestForgeConstants.Tests.editNoticeCornerRadius))
		.overlay {
			RoundedRectangle(cornerRadius: TestForgeConstants.Tests.editNoticeCornerRadius)
				.strokeBorder(.separator)
		}
		.clipShape(RoundedRectangle(cornerRadius: TestForgeConstants.Tests.editNoticeCornerRadius))
		.confirmationDialog("Replace the original screenshot?", isPresented: $viewModel.isOverwriteConfirmationPresented) {
			Button("Replace original", role: .destructive) {
				viewModel.saveOverOriginal()
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaSaveConfirm)
			Button("Save as copy") {
				viewModel.saveAsCopy()
			}
		} message: {
			Text("The run's own screenshot is overwritten with your annotations. This can't be undone.")
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaPanel)
		.tutorialAnchor(.testsMediaPanel)
	}

	private var headerRow: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Text("Proof")
				.font(.headline)
			if let item = viewModel.selectedItem {
				Text("\(item.name) · \(viewModel.positionText)")
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
					.truncationMode(.middle)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaFileName)
			}
			if let message = viewModel.message {
				Text(message)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaMessage)
			}
			Spacer()
			if viewModel.selectedItem != nil {
				fileButtons
			}
		}
		.labelStyle(.iconOnly)
		.padding(.horizontal, TestForgeConstants.Spacing.medium)
		.frame(height: TestForgeConstants.ProofViewer.controlBarHeight)
	}

	@ViewBuilder
	private var fileButtons: some View {
		Button("Previous", systemImage: "chevron.left") {
			viewModel.showPrevious()
		}
		.disabled((viewModel.selectedIndex ?? 0) == 0 || viewModel.isAnnotating)
		.help("Previous file")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaPrevious)
		Button("Next", systemImage: "chevron.right") {
			viewModel.showNext()
		}
		.disabled((viewModel.selectedIndex ?? 0) >= viewModel.items.count - 1 || viewModel.isAnnotating)
		.help("Next file")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaNext)
		Button("Annotate", systemImage: "pencil.tip.crop.circle") {
			viewModel.startAnnotating()
		}
		.disabled(!viewModel.canAnnotate)
		.help("Draw on this screenshot, then save it or save a copy")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaAnnotate)
		Button("Open in Default App", systemImage: "arrow.up.forward.app") {
			viewModel.openInDefaultApp()
		}
		.help("Open in Preview or QuickTime Player")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaOpen)
		Button("Show in Finder", systemImage: "folder") {
			viewModel.showInFinder()
		}
		.help("Show this file in Finder")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaReveal)
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.state {
			case .empty:
				ContentUnavailableView(
					"No proof yet",
					systemImage: "photo.on.rectangle",
					description: Text("Screenshots and videos from this case's runs show here.")
				)
			case .loading:
				ProgressView()
			case .failed(let message):
				ContentUnavailableView("Can't list the proof", systemImage: "exclamationmark.triangle", description: Text(message))
			case .loaded:
				mediaContent
		}
	}

	@ViewBuilder
	private var mediaContent: some View {
		if viewModel.isAnnotating,
			case .loaded(let image) = viewModel.imageViewModel.state {
			VStack(spacing: 0) {
				AnnotationCanvasView(
					image: image,
					strokes: viewModel.strokes,
					style: AnnotationCanvasStyle(tool: viewModel.tool, color: viewModel.color)
				) { stroke in
					viewModel.addStroke(stroke)
				}
				Divider()
				AnnotationToolbarView(viewModel: viewModel)
			}
		} else {
			switch viewModel.selectedItem?.kind {
				case .image:
					ProofImageView(viewModel: viewModel.imageViewModel)
				case .video:
					ProofVideoView(viewModel: viewModel.videoViewModel)
				case nil:
					Color.clear
			}
		}
	}
}
