import SwiftUI

/// Click the snapshot to drop numbered pins, write a note for each, then save or copy the annotated PNG.
struct MeasureSnapshotSheetView: View {
	@ObservedObject var viewModel: MeasureSnapshotViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			Text("Snapshot · \(viewModel.draft.elementTitle)")
				.font(.title3.weight(.semibold))
			HStack(alignment: .top, spacing: TestForgeConstants.Spacing.extraLarge) {
				ScrollView([.horizontal, .vertical]) {
					MeasureAnnotatedImageView(content: previewContent, displayScale: previewScale) { devicePoint in
						viewModel.addPin(at: devicePoint)
					}
				}
				.frame(width: TestForgeConstants.MeasureSnapshot.previewWidth, height: TestForgeConstants.MeasureSnapshot.previewHeight)
				.background(Color.secondary.opacity(TestForgeConstants.MeasureSnapshot.previewBackgroundOpacity))
				notesColumn
			}
			footer
		}
		.padding(TestForgeConstants.Spacing.extraLarge)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.measureSnapshotSheet)
	}

	private var previewContent: MeasureAnnotatedContent {
		MeasureAnnotatedContent(draft: viewModel.draft, pins: viewModel.pins, showsNotes: false)
	}

	/// Fits the crop into the preview box, never enlarging past twice its size.
	private var previewScale: CGFloat {
		let crop = viewModel.draft.cropRect
		guard crop.width > 0,
			crop.height > 0
		else {
			return 1
		}
		let fit = min(TestForgeConstants.MeasureSnapshot.previewWidth / crop.width, TestForgeConstants.MeasureSnapshot.previewHeight / crop.height)
		return min(fit, TestForgeConstants.MeasureSnapshot.maximumPreviewScale)
	}

	private var notesColumn: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Text("Notes")
				.font(.headline)
			if viewModel.pins.isEmpty {
				Label("Click the snapshot where a note belongs to drop pin 1.", systemImage: "mappin.and.ellipse")
					.foregroundStyle(.secondary)
			}
			ScrollView {
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
					ForEach(viewModel.pins) { pin in
						let actions = MeasureSnapshotNoteActions(
							update: { note in viewModel.updateNote(pinId: pin.id, note: note) },
							remove: { viewModel.removePin(pinId: pin.id) }
						)
						MeasureSnapshotNoteRowView(pin: pin, actions: actions)
					}
				}
			}
		}
		.frame(width: TestForgeConstants.MeasureSnapshot.notesWidth, alignment: .topLeading)
	}

	private var footer: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			if let savedFileURL = viewModel.savedFileURL {
				Label("Saved as \(savedFileURL.lastPathComponent)", systemImage: "checkmark.circle")
					.font(.callout)
					.foregroundStyle(.secondary)
					.lineLimit(1)
					.truncationMode(.middle)
					.help(savedFileURL.path)
				Button("Show in Finder", systemImage: "folder", action: viewModel.showSavedFileInFinder)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.measureSnapshotShowInFinder)
			}
			if let message = viewModel.message {
				Text(message)
					.font(.callout)
					.foregroundStyle(.secondary)
			} else if viewModel.hasEmptyNote {
				Label("A pin without a note is saved with an empty line.", systemImage: "exclamationmark.circle")
					.font(.callout)
					.foregroundStyle(.secondary)
			}
			Spacer()
			Button("Cancel", action: viewModel.close)
				.keyboardShortcut(.cancelAction)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.measureSnapshotCancel)
			Button(action: viewModel.copyImage) {
				Label("Copy image", systemImage: "doc.on.doc")
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.measureSnapshotCopy)
			Button(action: viewModel.saveImage) {
				Label("Save image…", systemImage: "square.and.arrow.down")
			}
			.keyboardShortcut(.defaultAction)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.measureSnapshotSave)
		}
	}
}
