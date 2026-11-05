import SwiftUI

/// A rounded box with its tail drawn as one outline, so the border runs around the tail without a seam.
struct ExplainCalloutShape: Shape {
	/// In the box's own coordinates; nil draws the plain rounded box.
	let tail: ExplainCaptionTail?

	let corner: CGFloat
	let tailHalfWidth: CGFloat

	func path(in rect: CGRect) -> Path {
		let radius = min(corner, rect.width / 2, rect.height / 2)
		var path = Path()
		path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
		addTail(on: .top, to: &path)
		path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
		path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + radius), radius: radius)
		addTail(on: .trailing, to: &path)
		path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
		path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - radius, y: rect.maxY), radius: radius)
		addTail(on: .bottom, to: &path)
		path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
		path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - radius), radius: radius)
		addTail(on: .leading, to: &path)
		path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
		path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + radius, y: rect.minY), radius: radius)
		path.closeSubpath()
		return path
	}

	/// Walks the outline clockwise, so each edge meets the tail's near base corner first.
	private func addTail(on edge: ExplainCaptionEdge, to path: inout Path) {
		guard let tail,
			tail.edge == edge
		else {
			return
		}
		let base = tail.base
		switch edge {
			case .top:
				path.addLine(to: CGPoint(x: base.x - tailHalfWidth, y: base.y))
				path.addLine(to: tail.tip)
				path.addLine(to: CGPoint(x: base.x + tailHalfWidth, y: base.y))
			case .trailing:
				path.addLine(to: CGPoint(x: base.x, y: base.y - tailHalfWidth))
				path.addLine(to: tail.tip)
				path.addLine(to: CGPoint(x: base.x, y: base.y + tailHalfWidth))
			case .bottom:
				path.addLine(to: CGPoint(x: base.x + tailHalfWidth, y: base.y))
				path.addLine(to: tail.tip)
				path.addLine(to: CGPoint(x: base.x - tailHalfWidth, y: base.y))
			case .leading:
				path.addLine(to: CGPoint(x: base.x, y: base.y + tailHalfWidth))
				path.addLine(to: tail.tip)
				path.addLine(to: CGPoint(x: base.x, y: base.y - tailHalfWidth))
		}
	}
}
