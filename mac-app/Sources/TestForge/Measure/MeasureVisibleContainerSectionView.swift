import SwiftUI

/// What the pixels show around the element: the card's frame, which of its edges were found, and its corner radius.
struct MeasureVisibleContainerSectionView: View {
	let container: VisibleContainer?

	var body: some View {
		Section("Visible container (from the screenshot)") {
			if let container {
				LabeledContent("Frame", value: MeasureFormatting.frameText(container.frame))
				LabeledContent("Edges found", value: edgesText(container: container))
				LabeledContent("Corner radius", value: radiusText(container: container))
			} else {
				Text("No card or panel edge found around this element; spacing is measured to the container the app reports.")
					.font(.callout)
					.foregroundStyle(.secondary)
			}
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.measureVisibleSection)
	}

	private func edgesText(container: VisibleContainer) -> String {
		let found = MeasureEdge.allCases.filter { container.detectedEdges.contains($0) }
		return found.map(\.plainTitle).joined(separator: ", ")
	}

	private func radiusText(container: VisibleContainer) -> String {
		guard let radius = container.cornerRadius else {
			return "—"
		}
		return "≈ \(MeasureFormatting.points(radius))"
	}
}

extension MeasureEdge {
	var plainTitle: String {
		switch self {
			case .top:
				return String(localized: "top")
			case .leading:
				return String(localized: "left")
			case .bottom:
				return String(localized: "bottom")
			case .trailing:
				return String(localized: "right")
		}
	}
}
