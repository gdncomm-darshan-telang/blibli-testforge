import SwiftUI

/// Who reported the box: the app, or the layer-colour pass with its border colour (nil while borders are hidden).
enum MeasureBoxKind: Equatable {
	case reported
	case unidentified(border: Color?)
}

/// Pink for elements the app reports, a dashed border for views found from layer colours.
struct MeasureElementBoxView: View {
	let frame: CGRect
	let isSelected: Bool
	let kind: MeasureBoxKind

	var body: some View {
		Rectangle()
			.stroke(strokeColor, style: StrokeStyle(lineWidth: lineWidth, dash: isDashed ? TestForgeConstants.Measure.visibleDash : []))
			.frame(width: frame.width, height: frame.height)
			.offset(x: frame.minX, y: frame.minY)
			.allowsHitTesting(false)
	}

	private var isDashed: Bool {
		kind != .reported && !isSelected
	}

	private var strokeColor: Color {
		if isSelected {
			return Color.accentColor
		}
		switch kind {
			case .reported:
				return Color.pink.opacity(TestForgeConstants.Measure.boxOpacity)
			case .unidentified(let border):
				return (border ?? .clear).opacity(TestForgeConstants.Measure.layerBoxOpacity)
		}
	}

	private var lineWidth: CGFloat {
		isSelected ? TestForgeConstants.Measure.selectedLineWidth : TestForgeConstants.Measure.boxLineWidth
	}
}
