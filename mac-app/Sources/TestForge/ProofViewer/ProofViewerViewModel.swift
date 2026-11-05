import Combine
import Foundation

/// The Proof window: one case's screenshots and videos, one shown at a time; builds and owns the image and video section models.
@MainActor
final class ProofViewerViewModel: ObservableObject {
	@Published private(set) var title = ""
	@Published private(set) var items: [ProofMediaItem] = []
	@Published private(set) var selectedIndex: Int?

	let imageViewModel = ProofImageViewModel()
	let videoViewModel = ProofVideoViewModel()

	private let desktop: DesktopActing

	init(desktop: DesktopActing) {
		self.desktop = desktop
	}

	var selectedItem: ProofMediaItem? {
		guard let selectedIndex else {
			return nil
		}
		return items[safe: selectedIndex]
	}

	var canShowPrevious: Bool {
		(selectedIndex ?? 0) > 0
	}

	var canShowNext: Bool {
		guard let selectedIndex else {
			return false
		}
		return selectedIndex < items.count - 1
	}

	var positionText: String {
		guard let selectedIndex else {
			return ""
		}
		return String(localized: "\(selectedIndex + 1) of \(items.count)")
	}

	func show(request: ProofViewerRequest) {
		title = request.title
		items = request.urls.map { ProofMediaItem(url: $0) }
		let index = items.firstIndex { $0.url == request.selectedURL } ?? 0
		select(index: index)
	}

	func select(index: Int) {
		guard let item = items[safe: index] else {
			return
		}
		selectedIndex = index
		switch item.kind {
			case .image:
				videoViewModel.unload()
				imageViewModel.load(url: item.url)
			case .video:
				imageViewModel.unload()
				videoViewModel.load(url: item.url)
		}
	}

	func showPrevious() {
		guard let selectedIndex,
			canShowPrevious
		else {
			return
		}
		select(index: selectedIndex - 1)
	}

	func showNext() {
		guard let selectedIndex,
			canShowNext
		else {
			return
		}
		select(index: selectedIndex + 1)
	}

	func openInDefaultApp() {
		guard let url = selectedItem?.url else {
			return
		}
		desktop.open(url: url)
	}

	func showInFinder() {
		guard let url = selectedItem?.url else {
			return
		}
		desktop.reveal(url: url)
	}

	/// Closing the window stops a video rather than leaving it playing unseen.
	func windowDidClose() {
		videoViewModel.unload()
	}
}
