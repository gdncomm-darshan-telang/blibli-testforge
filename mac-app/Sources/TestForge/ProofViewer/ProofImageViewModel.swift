import AppKit
import Combine

enum ProofImageState: Equatable {
	case empty
	case loading
	case loaded(NSImage)
	case failed(message: String)
}

/// One proof screenshot and its zoom; the view reports the fit scale because only it knows the window's size.
@MainActor
final class ProofImageViewModel: ObservableObject {
	@Published private(set) var state: ProofImageState = .empty
	@Published private(set) var zoom: ProofZoom = .fit

	private var loadTask: Task<Void, Never>?

	deinit {
		loadTask?.cancel()
	}

	func load(url: URL) {
		loadTask?.cancel()
		state = .loading
		zoom = .fit
		loadTask = Task { [weak self] in
			let data = await Task.detached(priority: .userInitiated) {
				try? Data(contentsOf: url)
			}.value
			guard !Task.isCancelled else {
				return
			}
			guard let data,
				let image = NSImage(data: data)
			else {
				self?.state = .failed(message: String(localized: "\(url.lastPathComponent) isn't on disk any more, or isn't an image."))
				return
			}
			self?.state = .loaded(image)
		}
	}

	func unload() {
		loadTask?.cancel()
		state = .empty
	}

	func zoomIn(fitScale: CGFloat) {
		let scale = currentScale(fitScale: fitScale) * TestForgeConstants.ProofViewer.zoomStep
		zoom = .scale(clamped(scale: scale))
	}

	func zoomOut(fitScale: CGFloat) {
		let scale = currentScale(fitScale: fitScale) / TestForgeConstants.ProofViewer.zoomStep
		zoom = .scale(clamped(scale: scale))
	}

	func fitToWindow() {
		zoom = .fit
	}

	func showActualSize() {
		zoom = .scale(1)
	}

	/// A trackpad pinch multiplies the zoom it started from.
	func magnify(from startScale: CGFloat, by magnification: CGFloat) {
		zoom = .scale(clamped(scale: startScale * magnification))
	}

	func currentScale(fitScale: CGFloat) -> CGFloat {
		switch zoom {
			case .fit:
				return fitScale
			case .scale(let scale):
				return scale
		}
	}

	private func clamped(scale: CGFloat) -> CGFloat {
		min(max(scale, TestForgeConstants.ProofViewer.minimumZoom), TestForgeConstants.ProofViewer.maximumZoom)
	}
}
