import SwiftUI

/// A line from the subtitle's tail to the pointed element, so the words and the place they describe read as one.
struct ExplainConnectorView: View {
	let tip: CGPoint
	let targetRect: CGRect
	let color: Color
	let width: CGFloat

	private var lineWidth: CGFloat {
		width * ExplainOverlayConstants.Connector.lineShare
	}

	private var dotSize: CGFloat {
		width * ExplainOverlayConstants.Connector.dotShare
	}

	/// The point of the element's outline nearest the tail.
	private var end: CGPoint {
		CGPoint(x: min(max(tip.x, targetRect.minX), targetRect.maxX), y: min(max(tip.y, targetRect.minY), targetRect.maxY))
	}

	/// No line when the tail already reaches the element: it would only cross it.
	private var hasRoom: Bool {
		hypot(end.x - tip.x, end.y - tip.y) > dotSize * 2
	}

	var body: some View {
		if hasRoom {
			ZStack(alignment: .topLeading) {
				Path { path in
					path.move(to: tip)
					path.addLine(to: end)
				}
				.stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [lineWidth * 3, lineWidth * 2]))
				.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.connectorLine)
				Circle()
					.fill(color)
					.frame(width: dotSize, height: dotSize)
					.position(end)
					.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.connectorDot)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.connector)
		}
	}
}
