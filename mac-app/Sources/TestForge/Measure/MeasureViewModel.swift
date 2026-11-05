import AppKit
import SwiftUI
import Foundation
import ImageIO

struct MeasureSnapshot: Equatable {
	let image: NSImage
	let screenSize: CGSize

	/// The same screenshot as raw pixels, for finding cards the accessibility tree doesn't report.
	let pixels: PixelGrid?

	/// What can be picked on the canvas: visible and one per frame.
	let elements: [MeasuredElement]

	/// Every element read, so the details pane can name ancestors that were filtered off the canvas.
	let allElements: [MeasuredElement]

	let capturedAt: Date

	/// Lets the layer pass take its own captures of the same device.
	let deviceId: String?

	var pixelsPerPoint: CGFloat {
		pixels?.pixelsPerPoint ?? 1
	}
}

/// The background pass that finds views without identifiers from a Color Blended Layers capture.
enum LayerPassState: Equatable {
	case idle
	case running
	case finished(addedCount: Int)
	case skipped(reason: String)
	case failed(message: String)
}

enum MeasureState: Equatable {
	case idle
	case loading
	case loaded(MeasureSnapshot)
	case failed(message: String)
}

struct MeasureSelection: Equatable {
	let element: MeasuredElement
	let containerTitle: String
	let gaps: [MeasureGap]
	let visibleContainer: VisibleContainer?

	/// Outermost first, ending with the element's parent.
	let ancestorTitles: [String]

	/// Every parent around the element, innermost first, out to the screen.
	let enclosures: [MeasureEnclosure]

	/// For text: the same spacing measured to the visible glyphs instead of the line box; empty for anything else.
	let glyphGaps: [MeasureGap]
}

struct MeasureDependencies {
	let locator: SimulatorLocating
	let screenReader: SimulatorScreenReading
	let desktop: DesktopActing
	let layerCapture: LayerCapturing

	/// True while a test or scan holds the simulator; tinting the screen then would spoil its screenshots.
	let isDeviceBusy: @MainActor () -> Bool
}

/// Measure (D-086 recommendation): a screenshot with every element's frame, in device points, from the Simulator's own tree.
/// Corner radius and constraint constants aren't in that tree; they would need an in-app inspector.
@MainActor
final class MeasureViewModel: ObservableObject {
	static let zoomRange: ClosedRange<CGFloat> = 1...8
	private static let zoomStep: CGFloat = 1.5
	private static let thinElementSide: CGFloat = 6
	private static let thinHitSlack: CGFloat = 2
	private static let textRole = "AXStaticText"

	@Published private(set) var state: MeasureState = .idle
	@Published private(set) var selection: MeasureSelection?
	@Published private(set) var layerPass: LayerPassState = .idle
	@Published private(set) var hovered: MeasureComparison?
	@Published var zoom: CGFloat = 1
	@Published var showsUnidentifiedBorders = false
	@Published var unidentifiedBorderColor = Color.purple

	/// The open snapshot sheet (D-124), or nil.
	@Published var snapshotSession: MeasureSnapshotViewModel?

	private let dependencies: MeasureDependencies
	private var loadTask: Task<Void, Never>?
	private var layerTask: Task<Void, Never>?

	init(dependencies: MeasureDependencies) {
		self.dependencies = dependencies
	}

	deinit {
		loadTask?.cancel()
		layerTask?.cancel()
	}

	var canZoomIn: Bool {
		zoom < Self.zoomRange.upperBound
	}

	var canZoomOut: Bool {
		zoom > Self.zoomRange.lowerBound
	}

	func zoomIn() {
		zoom = min(zoom * Self.zoomStep, Self.zoomRange.upperBound)
	}

	func zoomOut() {
		zoom = max(zoom / Self.zoomStep, Self.zoomRange.lowerBound)
	}

	func resetZoom() {
		zoom = Self.zoomRange.lowerBound
	}

	func refresh() {
		loadTask?.cancel()
		layerTask?.cancel()
		state = .loading
		selection = nil
		layerPass = .idle
		let dependencies = dependencies
		if !dependencies.locator.isTrusted {
			dependencies.locator.requestTrust()
		}
		loadTask = Task { [weak self] in
			let result = await Self.capture(dependencies: dependencies)
			guard !Task.isCancelled else {
				return
			}
			switch result {
				case .success(let snapshot):
					self?.state = .loaded(snapshot)
					self?.startLayerPass(snapshot: snapshot)
				case .failure(let error):
					self?.state = .failed(message: error.localizedDescription)
			}
		}
	}

	/// Picks the smallest element under the point, the one a designer means when clicking inside a card.
	func select(at devicePoint: CGPoint) {
		guard case .loaded(let snapshot) = state else {
			return
		}
		let hits = snapshot.elements.filter { Self.hitFrame(of: $0).contains(devicePoint) }
		guard let element = hits.min(by: { $0.frame.area < $1.frame.area }) else {
			selection = nil
				return
		}
		select(element: element, in: snapshot)
	}

	func select(elementId: Int) {
		guard case .loaded(let snapshot) = state,
			let element = snapshot.elements.first(where: { $0.id == elementId })
		else {
			return
		}
		select(element: element, in: snapshot)
	}

	/// With an element selected, measures from it to whatever is under the pointer; empty space compares with the screen.
	func hover(at devicePoint: CGPoint?) {
		guard let devicePoint,
			let selection,
			case .loaded(let snapshot) = state
		else {
			hovered = nil
			return
		}
		let target = Self.hoverTarget(at: devicePoint, selected: selection.element, snapshot: snapshot)
		let comparison = target.map { MeasureRelations.comparison(of: selection.element.frame, with: $0) }
		let hasGaps = comparison?.gaps.isEmpty == false
		hovered = hasGaps ? comparison?.displayed(pixelsPerPoint: snapshot.pixelsPerPoint) : nil
	}

	/// Opens the snapshot sheet for the selected view: cropped to its nearest parent, with its spacing drawn on.
	func startSnapshot() {
		guard let selection,
			case .loaded(let snapshot) = state
		else {
			return
		}
		let draft = MeasureSnapshotDraft(
			image: snapshot.image,
			screenSize: snapshot.screenSize,
			pixelsPerPoint: snapshot.pixelsPerPoint,
			cropRect: Self.cropRect(for: selection, screenSize: snapshot.screenSize),
			elementFrame: selection.element.frame,
			elementTitle: selection.element.label.isEmpty ? selection.element.title : selection.element.label,
			gaps: selection.gaps,
			capturedAt: snapshot.capturedAt
		)
		snapshotSession = MeasureSnapshotViewModel(draft: draft, desktop: dependencies.desktop) { [weak self] in
			self?.snapshotSession = nil
		}
	}

	/// The innermost parent that isn't the whole screen, with a margin; a view directly on the screen keeps a wider margin.
	private static func cropRect(for selection: MeasureSelection, screenSize: CGSize) -> CGRect {
		let screen = CGRect(origin: .zero, size: screenSize)
		let margin = TestForgeConstants.MeasureSnapshot.cropMargin
		let parent = selection.enclosures.first { $0.frame != screen }?.frame
		let base = parent.map { $0.union(selection.element.frame) } ?? selection.element.frame.insetBy(dx: -margin * 2, dy: -margin * 2)
		return base.insetBy(dx: -margin, dy: -margin).intersection(screen)
	}

	func copyDetails() {
		guard let selection else {
			return
		}
		let text = MeasureDetailsText.make(selection: selection)
		dependencies.desktop.copy(text: text)
	}

	private func select(element: MeasuredElement, in snapshot: MeasureSnapshot) {
		let structural = MeasureCalculator.container(of: element, in: snapshot.elements, screenSize: snapshot.screenSize)
		let visible = snapshot.pixels.flatMap { pixels in
			VisibleContainerDetector.detect(around: element.frame, within: structural.frame, grid: pixels)
		}
		let container = visible.map { MeasureContainer(visible: $0, structural: structural) } ?? structural
		let gaps = MeasureCalculator.gaps(for: element, in: snapshot.elements, container: container)
		let ancestors = MeasureCalculator.ancestors(of: element, in: snapshot.allElements).map(\.title)
		let visibleParent = visible.map { MeasureContainer(title: String(localized: "Visible container"), frame: $0.frame) }
		let context = MeasureRelationContext(elements: snapshot.allElements, screenSize: snapshot.screenSize)
		let extraParents = [structural] + (visibleParent.map { [$0] } ?? [])
		let enclosures = MeasureRelations.enclosures(of: element, extra: extraParents, context: context)
		let glyphGaps = Self.glyphGaps(for: element, container: container, snapshot: snapshot)
		hovered = nil
		selection = MeasureSelection(
			element: element,
			containerTitle: container.title,
			gaps: gaps.map { $0.displayed(pixelsPerPoint: snapshot.pixelsPerPoint) },
			visibleContainer: visible,
			ancestorTitles: ancestors,
			enclosures: enclosures.map { $0.displayed(pixelsPerPoint: snapshot.pixelsPerPoint) },
			glyphGaps: glyphGaps.map { $0.displayed(pixelsPerPoint: snapshot.pixelsPerPoint) }
		)
	}

	/// D-123: text is measured twice — to its line box (layout) and to the ink the eye sees.
	private static func glyphGaps(for element: MeasuredElement, container: MeasureContainer, snapshot: MeasureSnapshot) -> [MeasureGap] {
		guard element.role == textRole,
			let pixels = snapshot.pixels,
			let ink = TextInkDetector.inkBounds(of: element.frame, grid: pixels)
		else {
			return []
		}
		let inkElement = MeasuredElement(
			id: element.id,
			identifier: element.identifier,
			role: element.role,
			label: element.label,
			frame: ink,
			path: element.path,
			parentId: element.parentId,
			childCount: element.childCount
		)
		return MeasureCalculator.gaps(for: inkElement, in: snapshot.elements, container: container)
	}

	/// A 2 pt bar is hard to hit with a pointer, so thin elements take clicks a little beyond their edges.
	private static func hitFrame(of element: MeasuredElement) -> CGRect {
		let isThin = min(element.frame.width, element.frame.height) < thinElementSide
		return isThin ? element.frame.insetBy(dx: -thinHitSlack, dy: -thinHitSlack) : element.frame
	}

	/// The smallest other element under the point, or the screen when there is none; nil over the selection itself.
	private static func hoverTarget(at point: CGPoint, selected: MeasuredElement, snapshot: MeasureSnapshot) -> MeasureContainer? {
		let hits = snapshot.elements.filter { $0.frame.contains(point) && $0.frame != selected.frame }
		guard let element = hits.min(by: { $0.frame.area < $1.frame.area }) else {
			let isOverSelection = selected.frame.contains(point)
			return isOverSelection ? nil : MeasureContainer(title: String(localized: "Screen"), frame: CGRect(origin: .zero, size: snapshot.screenSize))
		}
		return MeasureContainer(title: element.title, frame: element.frame)
	}

	/// Shows the accessibility boxes at once, then adds boxes for views without identifiers when the pass finishes.
	private func startLayerPass(snapshot: MeasureSnapshot) {
		guard !dependencies.isDeviceBusy() else {
			layerPass = .skipped(reason: String(localized: "A test or scan is using the simulator."))
			return
		}
		guard let deviceId = snapshot.deviceId else {
			layerPass = .skipped(reason: String(localized: "The simulator's device id isn't known."))
			return
		}
		layerPass = .running
		let layerCapture = dependencies.layerCapture
		layerTask = Task { [weak self] in
			let result = await Self.analyseLayers(snapshot: snapshot, deviceId: deviceId, layerCapture: layerCapture)
			guard !Task.isCancelled else {
				return
			}
			self?.finishLayerPass(result: result, previous: snapshot)
		}
	}

	private func finishLayerPass(result: Result<MeasureSnapshot, Error>, previous: MeasureSnapshot) {
		switch result {
			case .success(let merged):
				layerPass = .finished(addedCount: merged.allElements.count - previous.allElements.count)
				state = .loaded(merged)
				if let selectedId = selection?.element.id {
					select(elementId: selectedId)
				}
			case .failure(let error):
				layerPass = .failed(message: error.localizedDescription)
		}
	}

	private nonisolated static func analyseLayers(
		snapshot: MeasureSnapshot,
		deviceId: String,
		layerCapture: LayerCapturing
	) async -> Result<MeasureSnapshot, Error> {
		do {
			let pair = try await layerCapture.capture(udid: deviceId)
			guard let plainImage = NSImage(data: pair.plain),
				let plainGrid = pixelGrid(imageData: pair.plain, screenSize: snapshot.screenSize),
				let tintedGrid = pixelGrid(imageData: pair.tinted, screenSize: snapshot.screenSize)
			else {
				throw MeasureError.unreadableScreenshot
			}
			let layers = BlendedLayerAnalyzer.layers(in: tintedGrid)
			let plainImageForText = plainCGImage(imageData: pair.plain)
			let textLines = plainImageForText.map { TextRegionDetector.lineBoxes(in: $0, screenSize: snapshot.screenSize) } ?? []
			let merged = LayerElementMerger.merge(layers: layers, into: snapshot.allElements, textLines: textLines)
			let mergedSnapshot = MeasureSnapshot(
				image: plainImage,
				screenSize: snapshot.screenSize,
				pixels: plainGrid,
				elements: MeasureCalculator.selectable(elements: merged, screenSize: snapshot.screenSize),
				allElements: merged,
				capturedAt: snapshot.capturedAt,
				deviceId: snapshot.deviceId
			)
			return .success(mergedSnapshot)
		} catch {
			return .failure(error)
		}
	}

	private nonisolated static func capture(dependencies: MeasureDependencies) async -> Result<MeasureSnapshot, Error> {
		do {
			// D-120: the device in the Simulator window, from CoreSimulator — no test runner, any simulator.
			let screen = try dependencies.screenReader.windowDevice()
			let imageData = try await dependencies.screenReader.screenshot(udid: screen.udid ?? "")
			guard let image = NSImage(data: imageData) else {
				throw MeasureError.unreadableScreenshot
			}
			let pixels = Self.pixelGrid(imageData: imageData, screenSize: screen.size)
			let locator = dependencies.locator
			let geometry = try locator.geometry()
			let rawElements = try locator.elements()
			let mapping = ScreenMapping(screenFrame: geometry.screenFrame, devicePoints: screen.size)
			guard mapping.isCalibrated else {
				throw MeasureError.notCalibrated
			}
			let measured = rawElements.map { raw in
				MeasuredElement(
					id: raw.id,
					identifier: raw.identifier,
					role: raw.role,
					label: raw.label,
					frame: mapping.deviceRect(forMacRect: raw.frame),
					path: raw.path,
					parentId: raw.parentId,
					childCount: raw.childCount
				)
			}
			let elements = MeasureCalculator.selectable(elements: measured, screenSize: screen.size)
			let snapshot = MeasureSnapshot(
				image: image,
				screenSize: screen.size,
				pixels: pixels,
				elements: elements,
				allElements: measured,
				capturedAt: Date(),
				deviceId: screen.udid
			)
			return .success(snapshot)
		} catch {
			return .failure(error)
		}
	}

	private nonisolated static func pixelGrid(imageData: Data, screenSize: CGSize) -> PixelGrid? {
		guard let cgImage = plainCGImage(imageData: imageData) else {
			return nil
		}
		return PixelGrid(image: cgImage, screenSize: screenSize)
	}

	private nonisolated static func plainCGImage(imageData: Data) -> CGImage? {
		guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
			return nil
		}
		return CGImageSourceCreateImageAtIndex(source, 0, nil)
	}
}

enum MeasureError: LocalizedError {
	case unreadableScreenshot
	case notCalibrated

	var errorDescription: String? {
		switch self {
			case .unreadableScreenshot:
				return String(localized: "The simulator screenshot couldn't be read.")
			case .notCalibrated:
				return String(localized: "The Simulator window doesn't match the device's shape; open the device window and try again.")
		}
	}
}

/// Plain text of everything the details pane shows, for pasting into a bug or design review.
enum MeasureDetailsText {
	static func make(selection: MeasureSelection) -> String {
		let element = selection.element
		var lines = [
			element.title,
			"Frame (pt): \(MeasureFormatting.frameText(element.frame))",
			"Inside: \(selection.containerTitle)",
			"Path: \((selection.ancestorTitles + [element.title]).joined(separator: " › "))",
			"Children: \(element.childCount)"
		]
		if let visible = selection.visibleContainer {
			lines.append("Visible container (pt): \(MeasureFormatting.frameText(visible.frame))")
			if let radius = visible.cornerRadius {
				lines.append("Corner radius (approx.): \(MeasureFormatting.points(radius))")
			}
		}
		lines += selection.gaps.map { "\($0.edge.rawValue): \(MeasureFormatting.points($0.distance)) to \($0.toTitle)" }
		lines += selection.enclosures.map { "Inset in \($0.title): \(MeasureFormatting.insetsText($0.insets))" }
		return lines.joined(separator: "\n")
	}
}
