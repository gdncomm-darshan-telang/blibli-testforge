import SwiftUI

/// A proof screenshot that fits the window by default, zooms with the bar, ⌘+ / ⌘−, a pinch or a double-click, and pans by scrolling.
struct ProofImageView: View {
	@ObservedObject var viewModel: ProofImageViewModel
	@State private var pinchStartScale: CGFloat?

	var body: some View {
		GeometryReader { geometry in
			switch viewModel.state {
				case .empty:
					Color.clear
				case .loading:
					ProgressView()
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				case .failed(let message):
					ContentUnavailableView("Can't show this file", systemImage: "photo.badge.exclamationmark", description: Text(message))
				case .loaded(let image):
					loadedContent(image: image, containerSize: geometry.size)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerImage)
	}

	private func loadedContent(image: NSImage, containerSize: CGSize) -> some View {
		let barHeight = TestForgeConstants.ProofViewer.controlBarHeight
		let imageAreaSize = CGSize(width: containerSize.width, height: max(containerSize.height - barHeight, 1))
		let fitScale = fitScale(imageSize: image.size, containerSize: imageAreaSize)
		let scale = viewModel.currentScale(fitScale: fitScale)
		let actions = ProofZoomActions(
			zoomIn: { viewModel.zoomIn(fitScale: fitScale) },
			zoomOut: { viewModel.zoomOut(fitScale: fitScale) },
			fit: { viewModel.fitToWindow() },
			actualSize: { viewModel.showActualSize() }
		)
		return VStack(spacing: 0) {
			ScrollView([.horizontal, .vertical]) {
				Image(nsImage: image)
					.resizable()
					.interpolation(scale > TestForgeConstants.ProofViewer.pixelatedZoom ? .none : .high)
					.frame(width: image.size.width * scale, height: image.size.height * scale)
					.frame(minWidth: imageAreaSize.width, minHeight: imageAreaSize.height)
					.onTapGesture(count: 2) {
						if case .fit = viewModel.zoom {
							viewModel.showActualSize()
						} else {
							viewModel.fitToWindow()
						}
					}
			}
			.frame(height: imageAreaSize.height)
			.gesture(magnifyGesture(currentScale: scale))
			Divider()
			ProofZoomBarView(zoomPercent: Int((scale * 100).rounded()), actions: actions)
				.frame(height: barHeight)
		}
	}

	private func magnifyGesture(currentScale: CGFloat) -> some Gesture {
		MagnifyGesture()
			.onChanged { value in
				let startScale = pinchStartScale ?? currentScale
				pinchStartScale = startScale
				viewModel.magnify(from: startScale, by: value.magnification)
			}
			.onEnded { _ in
				pinchStartScale = nil
			}
	}

	private func fitScale(imageSize: CGSize, containerSize: CGSize) -> CGFloat {
		guard imageSize.width > 0,
			imageSize.height > 0
		else {
			return 1
		}
		return min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
	}
}
