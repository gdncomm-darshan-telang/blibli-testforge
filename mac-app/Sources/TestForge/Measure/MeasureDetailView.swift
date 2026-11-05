import SwiftUI

struct MeasureDetailContent {
	let snapshot: MeasureSnapshot
	let selection: MeasureSelection?
	let hovered: MeasureComparison?
}

struct MeasureDetailView: View {
	let content: MeasureDetailContent
	let onCopy: () -> Void

	var body: some View {
		Form {
			Section("Screen") {
				LabeledContent("Size", value: MeasureFormatting.sizeText(content.snapshot.screenSize))
				LabeledContent("Elements", value: "\(content.snapshot.elements.count)")
				LabeledContent("Captured", value: content.snapshot.capturedAt.formatted(date: .omitted, time: .standard))
			}
			if let selection = content.selection {
				selectedSections(selection: selection)
				MeasureParentsSectionView(enclosures: selection.enclosures)
				MeasureComparisonSectionView(comparison: content.hovered)
				MeasureVisibleContainerSectionView(container: selection.visibleContainer)
			} else {
				Section {
					Text("Click an element to see its size and spacing to everything around it.")
						.foregroundStyle(.secondary)
				}
			}
			Section {
				Text(accuracyNote)
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
		}
		.formStyle(.grouped)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.measureDetail)
	}

	private var accuracyNote: LocalizedStringKey {
		"""
		Spacing is shown on the spacing scale — 0, 1, 2, 4, then multiples of 4 — from rendered positions, not constraint \
		constants. Cards the app doesn't report are found in the screenshot (dashed borders when Views without IDs is on), \
		so their edges and corner radius are approximate.
		"""
	}

	@ViewBuilder
	private func selectedSections(selection: MeasureSelection) -> some View {
		let element = selection.element
		Section("Element") {
			HStack {
				Text(element.title)
					.font(.headline)
					.textSelection(.enabled)
				Spacer()
				Button(action: onCopy) {
					Label("Copy details", systemImage: "doc.on.doc")
				}
				.labelStyle(.iconOnly)
				.help("Copy everything shown for this element")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.measureCopyButton)
			}
			LabeledContent("Identifier", value: element.identifier.isEmpty ? "—" : element.identifier)
			LabeledContent("Role", value: element.role)
			LabeledContent("Label", value: element.label.isEmpty ? "—" : element.label)
		}
		Section("Geometry (points)") {
			LabeledContent("Frame", value: MeasureFormatting.frameText(element.frame))
			LabeledContent("Size", value: MeasureFormatting.sizeText(element.frame.size))
			LabeledContent("Center", value: MeasureFormatting.pointText(CGPoint(x: element.frame.midX, y: element.frame.midY)))
			LabeledContent("Inside", value: selection.containerTitle)
		}
		Section("Spacing to nearest (points)") {
			ForEach(selection.gaps) { gap in
				LabeledContent(gap.edge.title) {
					Text("\(MeasureFormatting.points(gap.distance)) to \(gap.toTitle)")
						.lineLimit(2)
				}
			}
		}
		if !selection.glyphGaps.isEmpty {
			Section {
				ForEach(selection.glyphGaps) { gap in
					LabeledContent(gap.edge.title) {
						Text("\(MeasureFormatting.points(gap.distance)) to \(gap.toTitle)")
							.lineLimit(2)
					}
				}
			} header: {
				Text("Spacing to glyphs (points)")
			} footer: {
				Text("Measured to the visible letters. The values above use the text's line box, which is taller by the font's leading.")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.measureGlyphGaps)
		}
		Section("Hierarchy") {
			Text((selection.ancestorTitles + [element.title]).joined(separator: " › "))
				.font(.callout)
				.textSelection(.enabled)
			LabeledContent("Depth", value: "\(element.path.count)")
			LabeledContent("Children", value: "\(element.childCount)")
		}
	}
}

extension MeasureEdge {
	var title: LocalizedStringKey {
		switch self {
			case .top:
				return "Top"
			case .leading:
				return "Left"
			case .bottom:
				return "Bottom"
			case .trailing:
				return "Right"
		}
	}
}
