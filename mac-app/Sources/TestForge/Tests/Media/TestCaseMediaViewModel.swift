import AppKit
import Combine

enum TestCaseMediaState: Equatable {
	case empty
	case loading
	case loaded
	case failed(message: String)
}

/// D-183: the selected case's proof under its detail — view or play one file at a time, annotate a screenshot and save it.
/// Whole-class `@MainActor`: it only maps files to published state; the image and video models do the loading.
@MainActor
final class TestCaseMediaViewModel: ObservableObject {
	@Published private(set) var state: TestCaseMediaState = .empty
	@Published private(set) var items: [ProofMediaItem] = []
	@Published private(set) var selectedIndex: Int?
	@Published private(set) var isAnnotating = false
	@Published private(set) var strokes: [AnnotationStroke] = []
	@Published private(set) var message: String?
	@Published var tool: AnnotationTool = .pen
	@Published var color: AnnotationColor = .red
	@Published var isOverwriteConfirmationPresented = false

	let imageViewModel = ProofImageViewModel()
	let videoViewModel = ProofVideoViewModel()

	private let service: TestCaseActing
	private let desktop: DesktopActing
	private let imageStore: AnnotatedImageSaving
	private var caseId: String?
	private var loadTask: Task<Void, Never>?

	/// After a save the list reloads; the saved file is shown once it is listed.
	private var pendingSelectionURL: URL?

	init(service: TestCaseActing, desktop: DesktopActing, imageStore: AnnotatedImageSaving = AnnotatedImageStore()) {
		self.service = service
		self.desktop = desktop
		self.imageStore = imageStore
	}

	deinit {
		loadTask?.cancel()
	}

	var selectedItem: ProofMediaItem? {
		guard let selectedIndex else {
			return nil
		}
		return items[safe: selectedIndex]
	}

	var canAnnotate: Bool {
		selectedItem?.kind == .image && !isAnnotating
	}

	var canSaveAnnotations: Bool {
		isAnnotating && !strokes.isEmpty
	}

	var positionText: String {
		guard let selectedIndex else {
			return ""
		}
		return String(localized: "\(selectedIndex + 1) of \(items.count)")
	}

	/// Reloads when the case changes or its proof count does, keeping the shown file when it is still there.
	func load(caseId: String?, keepingSelection: Bool = false) {
		let previousURL = keepingSelection ? selectedItem?.url : nil
		self.caseId = caseId
		loadTask?.cancel()
		endAnnotating()
		guard let caseId else {
			clear()
			return
		}
		if !keepingSelection {
			state = .loading
		}
		let service = service
		loadTask = Task { [weak self] in
			do {
				let urls = try await service.media(caseId: caseId)
				guard !Task.isCancelled else {
					return
				}
				self?.show(urls: urls, preferring: previousURL)
			} catch {
				self?.state = .failed(message: error.localizedDescription)
			}
		}
	}

	func select(index: Int) {
		guard let item = items[safe: index] else {
			return
		}
		endAnnotating()
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
		guard let selectedIndex else {
			return
		}
		select(index: selectedIndex - 1)
	}

	func showNext() {
		guard let selectedIndex else {
			return
		}
		select(index: selectedIndex + 1)
	}

	func startAnnotating() {
		guard canAnnotate else {
			return
		}
		imageViewModel.fitToWindow()
		strokes = []
		message = nil
		isAnnotating = true
	}

	func endAnnotating() {
		isAnnotating = false
		strokes = []
	}

	func addStroke(_ stroke: AnnotationStroke) {
		strokes.append(stroke)
	}

	func undoStroke() {
		_ = strokes.popLast()
	}

	func clearStrokes() {
		strokes = []
	}

	func requestOverwrite() {
		guard canSaveAnnotations else {
			return
		}
		isOverwriteConfirmationPresented = true
	}

	func saveOverOriginal() {
		guard let url = selectedItem?.url else {
			return
		}
		save(to: url)
	}

	func saveAsCopy() {
		guard let url = selectedItem?.url else {
			return
		}
		save(to: imageStore.copyURL(for: url))
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

	/// Leaving the case stops a video rather than leaving it playing unseen.
	func stopPlayback() {
		videoViewModel.unload()
	}

	private func save(to target: URL) {
		guard case .loaded(let image) = imageViewModel.state,
			let data = AnnotationRenderer.render(image: image, strokes: strokes, fileExtension: target.pathExtension)
		else {
			message = String(localized: "Couldn't draw the annotations into the image.")
			return
		}
		do {
			try imageStore.write(data: data, to: target)
			message = String(localized: "Saved \(target.lastPathComponent)")
			pendingSelectionURL = target
			load(caseId: caseId, keepingSelection: true)
		} catch {
			message = error.localizedDescription
		}
	}

	/// A saved annotation is shown afresh; otherwise the file on screen keeps playing or stays zoomed.
	private func show(urls: [URL], preferring previousURL: URL?) {
		let shownURL = selectedItem?.url
		let savedURL = pendingSelectionURL
		pendingSelectionURL = nil
		items = urls.map { ProofMediaItem(url: $0) }
		state = items.isEmpty ? .empty : .loaded
		guard let index = index(of: savedURL ?? previousURL) ?? (items.isEmpty ? nil : 0) else {
			clear()
			return
		}
		if savedURL != nil || items[safe: index]?.url != shownURL {
			select(index: index)
		} else {
			selectedIndex = index
		}
	}

	private func index(of url: URL?) -> Int? {
		guard let url else {
			return nil
		}
		return items.firstIndex { $0.url.standardizedFileURL == url.standardizedFileURL }
	}

	private func clear() {
		items = []
		selectedIndex = nil
		state = .empty
		imageViewModel.unload()
		videoViewModel.unload()
	}
}
