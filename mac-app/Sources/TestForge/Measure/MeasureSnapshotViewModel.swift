import AppKit
import Combine
import SwiftUI

/// The snapshot sheet (D-124): drop numbered pins on the selected view's snapshot, write a note per pin, then save or
/// copy one PNG with the spacing, the pins and the notes burnt in.
@MainActor
final class MeasureSnapshotViewModel: ObservableObject, Identifiable {
	@Published private(set) var pins: [MeasurePin] = []
	@Published private(set) var message: String?

	/// The last saved file, kept on screen with Show in Finder until the next save (D-146).
	@Published private(set) var savedFileURL: URL?

	let id = UUID()
	let draft: MeasureSnapshotDraft

	private let desktop: DesktopActing
	private let onClose: () -> Void

	init(draft: MeasureSnapshotDraft, desktop: DesktopActing, onClose: @escaping () -> Void) {
		self.draft = draft
		self.desktop = desktop
		self.onClose = onClose
	}

	var hasEmptyNote: Bool {
		pins.contains { $0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
	}

	func addPin(at devicePoint: CGPoint) {
		let number = (pins.map(\.id).max() ?? 0) + 1
		pins.append(MeasurePin(id: number, position: devicePoint, note: ""))
	}

	func updateNote(pinId: Int, note: String) {
		guard let index = pins.firstIndex(where: { $0.id == pinId }) else {
			return
		}
		pins[index].note = note
	}

	/// Renumbers the rest so the image never shows a gap in the sequence.
	func removePin(pinId: Int) {
		let kept = pins.filter { $0.id != pinId }
		pins = kept.enumerated().map { offset, pin in
			MeasurePin(id: offset + 1, position: pin.position, note: pin.note)
		}
	}

	func saveImage() {
		guard let data = renderedPNG() else {
			message = String(localized: "The image couldn't be drawn.")
			return
		}
		let fileName = suggestedFileName
		let desktop = desktop
		Task { [weak self] in
			do {
				if let savedURL = try await desktop.saveImage(pngData: data, suggestedFileName: fileName) {
					self?.savedFileURL = savedURL
					self?.message = nil
				}
			} catch {
				self?.message = error.localizedDescription
			}
		}
	}

	func copyImage() {
		guard let data = renderedPNG() else {
			message = String(localized: "The image couldn't be drawn.")
			return
		}
		desktop.copy(pngData: data)
		message = String(localized: "Copied — paste it into Jira, Slack or a doc.")
	}

	func showSavedFileInFinder() {
		guard let savedFileURL else {
			return
		}
		desktop.reveal(url: savedFileURL)
	}

	func close() {
		onClose()
	}

	/// Rendered at the device's own pixel density, so the screenshot part stays as sharp as the capture.
	private func renderedPNG() -> Data? {
		let content = MeasureAnnotatedContent(draft: draft, pins: pins, showsNotes: true)
		let renderer = ImageRenderer(content: MeasureAnnotatedImageView(content: content, displayScale: 1).environment(\.colorScheme, .light))
		renderer.scale = max(draft.pixelsPerPoint, 1)
		guard let image = renderer.cgImage else {
			return nil
		}
		let bitmap = NSBitmapImageRep(cgImage: image)
		return bitmap.representation(using: .png, properties: [:])
	}

	private var suggestedFileName: String {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
		let safeTitle = draft.elementTitle.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
		return "Measure_\(safeTitle)_\(formatter.string(from: draft.capturedAt)).png"
	}
}
