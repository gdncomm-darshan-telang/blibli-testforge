import SwiftUI

/// The card found in the screenshot, dashed so it reads as detected rather than reported by the app.
/// Only edges seen in the pixels are drawn; the full rounded outline needs all four.
struct MeasureVisibleContainerView: View {
	let container: VisibleContainer
	let scale: CGFloat
	let color: Color

	var body: some View {
		outline
			.stroke(
				color,
				style: StrokeStyle(lineWidth: TestForgeConstants.Measure.visibleLineWidth, dash: TestForgeConstants.Measure.visibleDash)
			)
			.allowsHitTesting(false)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.measureVisibleContainer)
	}

	private var outline: Path {
		let frame = CGRect(
			x: container.frame.minX * scale,
			y: container.frame.minY * scale,
			width: container.frame.width * scale,
			height: container.frame.height * scale
		)
		let isComplete = container.detectedEdges.count == MeasureEdge.allCases.count
		if isComplete {
			let radius = (container.cornerRadius ?? 0) * scale
			return Path(roundedRect: frame, cornerRadius: radius)
		}
		var path = Path()
		for edge in MeasureEdge.allCases where container.detectedEdges.contains(edge) {
			let side = sideEnds(edge: edge, frame: frame)
			path.move(to: side.start)
			path.addLine(to: side.end)
		}
		return path
	}

	private func sideEnds(edge: MeasureEdge, frame: CGRect) -> (start: CGPoint, end: CGPoint) {
		switch edge {
			case .top:
				return (CGPoint(x: frame.minX, y: frame.minY), CGPoint(x: frame.maxX, y: frame.minY))
			case .bottom:
				return (CGPoint(x: frame.minX, y: frame.maxY), CGPoint(x: frame.maxX, y: frame.maxY))
			case .leading:
				return (CGPoint(x: frame.minX, y: frame.minY), CGPoint(x: frame.minX, y: frame.maxY))
			case .trailing:
				return (CGPoint(x: frame.maxX, y: frame.minY), CGPoint(x: frame.maxX, y: frame.maxY))
		}
	}
}
