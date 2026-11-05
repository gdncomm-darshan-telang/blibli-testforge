import AppKit

/// What a Measure snapshot shows (D-124): the screenshot cropped around the selected view, with its spacing drawn on.
struct MeasureSnapshotDraft: Equatable {
	let image: NSImage
	let screenSize: CGSize
	let pixelsPerPoint: CGFloat

	/// Device points; the part of the screen the snapshot keeps.
	let cropRect: CGRect

	let elementFrame: CGRect
	let elementTitle: String
	let gaps: [MeasureGap]
	let capturedAt: Date
}

/// A numbered marker the person drops on the snapshot, with its note.
struct MeasurePin: Equatable, Identifiable {
	let id: Int

	/// Device points, so the pin stays put at any preview size.
	let position: CGPoint

	var note: String
}

/// Everything the annotated image draws; `showsNotes` adds the numbered notes list under the screenshot (the export).
struct MeasureAnnotatedContent {
	let draft: MeasureSnapshotDraft
	let pins: [MeasurePin]
	let showsNotes: Bool
}
