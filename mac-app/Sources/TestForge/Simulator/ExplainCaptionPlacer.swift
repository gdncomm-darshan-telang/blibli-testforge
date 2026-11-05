import AppKit

/// The side of the subtitle box that faces the element, where its tail sits.
enum ExplainCaptionEdge: Equatable {
	case top
	case bottom
	case leading
	case trailing
}

struct ExplainCaptionTail: Equatable {
	/// Middle of the tail's base, on the box edge.
	let base: CGPoint

	let tip: CGPoint
	let edge: ExplainCaptionEdge
}

/// Where the subtitle box goes for this step; panel points, top-left origin.
struct ExplainCaptionPlacement: Equatable {
	let frame: CGRect

	/// Nil when there is no element, or the box had to sit over it.
	let tail: ExplainCaptionTail?
}

struct ExplainCaptionLayoutInputs {
	let text: String

	/// The drawn outline of the focused element; nil when the step points at nothing.
	let target: CGRect?

	/// Other drawings next to the element (its badge) the box must not cover.
	let avoid: [CGRect]

	let screen: CGSize
}

/// Picks the subtitle's spot per step from the focused element's position, so it never covers what it talks about.
enum ExplainCaptionPlacer {
	private typealias Metrics = ExplainOverlayConstants.Caption

	private struct Space {
		let text: String
		let size: CGSize
		let bounds: CGRect
		let width: CGFloat
	}

	/// The room beside the element: `edgeX` is the box's inner edge, `gap` away from the element.
	private struct SideSlot {
		let room: CGFloat
		let edgeX: CGFloat
		let isTrailing: Bool
	}

	private struct Candidate {
		let frame: CGRect
		let edge: ExplainCaptionEdge
	}

	static func placement(inputs: ExplainCaptionLayoutInputs) -> ExplainCaptionPlacement {
		let width = inputs.screen.width
		let size = boxSize(text: inputs.text, width: width)
		let bounds = safeBounds(screen: inputs.screen)
		guard let target = inputs.target else {
			let frame = CGRect(x: bounds.midX - size.width / 2, y: bounds.maxY - size.height, width: size.width, height: size.height)
			return ExplainCaptionPlacement(frame: frame, tail: nil)
		}
		let space = Space(text: inputs.text, size: size, bounds: bounds, width: width)
		let occupied = inputs.avoid.reduce(target) { $0.union($1) }
		let candidates = orderedCandidates(space: space, target: target, occupied: occupied)
		if let fitting = candidates.first(where: { bounds.contains($0.frame) }) {
			return ExplainCaptionPlacement(frame: fitting.frame, tail: tail(for: fitting, target: target, width: width))
		}
		return fallback(space: space, target: target)
	}

	/// `maxBoxWidth` narrows a box that sits beside the element; it defaults to the subtitle's full width.
	static func boxSize(text: String, width: CGFloat, maxBoxWidth: CGFloat? = nil) -> CGSize {
		let fontSize = width * Metrics.fontShare
		let horizontalPad = fontSize * Metrics.horizontalPadFontShare
		let verticalPad = fontSize * Metrics.verticalPadFontShare
		let maxTextWidth = min(maxBoxWidth ?? .greatestFiniteMagnitude, width * Metrics.maxWidthShare) - horizontalPad * 2
		let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
		let measured = (text as NSString).boundingRect(
			with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
			options: [.usesLineFragmentOrigin, .usesFontLeading],
			attributes: [.font: font]
		)
		// A little slack so SwiftUI's own line breaking never needs one more line than measured here.
		let textWidth = min(ceil(measured.width) + fontSize * Metrics.measureSlackFontShare, maxTextWidth)
		return CGSize(width: textWidth + horizontalPad * 2, height: ceil(measured.height) + verticalPad * 2)
	}

	/// The screen minus the status bar and home indicator, so a box is never under either.
	private static func safeBounds(screen: CGSize) -> CGRect {
		let margin = screen.width * Metrics.marginShare
		let top = screen.width * Metrics.topInsetShare
		let bottom = screen.width * Metrics.bottomInsetShare
		return CGRect(x: margin, y: top, width: screen.width - margin * 2, height: screen.height - top - bottom)
	}

	/// Below or above first, on the side of the element with more room, then beside it on the wider side.
	private static func orderedCandidates(space: Space, target: CGRect, occupied: CGRect) -> [Candidate] {
		let size = space.size
		let bounds = space.bounds
		let gap = space.width * Metrics.gapShare
		let centeredX = clamp(target.midX - size.width / 2, low: bounds.minX, high: bounds.maxX - size.width)
		let below = Candidate(frame: CGRect(origin: CGPoint(x: centeredX, y: occupied.maxY + gap), size: size), edge: .top)
		let above = Candidate(frame: CGRect(origin: CGPoint(x: centeredX, y: occupied.minY - gap - size.height), size: size), edge: .bottom)
		let hasMoreRoomBelow = bounds.maxY - occupied.maxY >= occupied.minY - bounds.minY
		let hasMoreRoomTrailing = bounds.maxX - occupied.maxX >= occupied.minX - bounds.minX
		let vertical = hasMoreRoomBelow ? [below, above] : [above, below]
		let trailingSlot = SideSlot(room: bounds.maxX - occupied.maxX - gap, edgeX: occupied.maxX + gap, isTrailing: true)
		let leadingSlot = SideSlot(room: occupied.minX - gap - bounds.minX, edgeX: occupied.minX - gap, isTrailing: false)
		let trailing = sideCandidate(space: space, target: target, slot: trailingSlot)
		let leading = sideCandidate(space: space, target: target, slot: leadingSlot)
		let sides = hasMoreRoomTrailing ? [trailing, leading] : [leading, trailing]
		return vertical + sides.compactMap { $0 }
	}

	/// A box beside the element, narrowed to the room there; nil when that room is too thin to read.
	private static func sideCandidate(space: Space, target: CGRect, slot: SideSlot) -> Candidate? {
		guard slot.room >= space.width * Metrics.minSideWidthShare else {
			return nil
		}
		let size = boxSize(text: space.text, width: space.width, maxBoxWidth: slot.room)
		let bounds = space.bounds
		let y = clamp(target.midY - size.height / 2, low: bounds.minY, high: bounds.maxY - size.height)
		let x = slot.isTrailing ? slot.edgeX : slot.edgeX - size.width
		return Candidate(frame: CGRect(origin: CGPoint(x: x, y: y), size: size), edge: slot.isTrailing ? .leading : .trailing)
	}

	/// The element fills most of the screen: sit at the top or bottom, whichever covers less of it.
	private static func fallback(space: Space, target: CGRect) -> ExplainCaptionPlacement {
		let size = space.size
		let bounds = space.bounds
		let x = clamp(target.midX - size.width / 2, low: bounds.minX, high: bounds.maxX - size.width)
		let top = CGRect(x: x, y: bounds.minY, width: size.width, height: size.height)
		let bottom = CGRect(x: x, y: bounds.maxY - size.height, width: size.width, height: size.height)
		let frame = coveredArea(top, target) < coveredArea(bottom, target) ? top : bottom
		guard !frame.intersects(target) else {
			return ExplainCaptionPlacement(frame: frame, tail: nil)
		}
		let candidate = Candidate(frame: frame, edge: frame.midY > target.midY ? .top : .bottom)
		return ExplainCaptionPlacement(frame: frame, tail: tail(for: candidate, target: target, width: space.width))
	}

	/// Aims at the element's middle, kept clear of the box's rounded corners.
	private static func tail(for candidate: Candidate, target: CGRect, width: CGFloat) -> ExplainCaptionTail {
		let frame = candidate.frame
		let edge = candidate.edge
		let length = width * Metrics.tailLengthShare
		let reserve = width * (Metrics.tailHalfWidthShare + Metrics.fontShare * Metrics.cornerFontShare)
		let x = clamp(target.midX, low: frame.minX + reserve, high: frame.maxX - reserve)
		let y = clamp(target.midY, low: frame.minY + reserve, high: frame.maxY - reserve)
		switch edge {
			case .top:
				return ExplainCaptionTail(base: CGPoint(x: x, y: frame.minY), tip: CGPoint(x: x, y: frame.minY - length), edge: edge)
			case .bottom:
				return ExplainCaptionTail(base: CGPoint(x: x, y: frame.maxY), tip: CGPoint(x: x, y: frame.maxY + length), edge: edge)
			case .leading:
				return ExplainCaptionTail(base: CGPoint(x: frame.minX, y: y), tip: CGPoint(x: frame.minX - length, y: y), edge: edge)
			case .trailing:
				return ExplainCaptionTail(base: CGPoint(x: frame.maxX, y: y), tip: CGPoint(x: frame.maxX + length, y: y), edge: edge)
		}
	}

	private static func coveredArea(_ frame: CGRect, _ target: CGRect) -> CGFloat {
		let overlap = frame.intersection(target)
		return overlap.isNull ? 0 : overlap.width * overlap.height
	}

	private static func clamp(_ value: CGFloat, low: CGFloat, high: CGFloat) -> CGFloat {
		high < low ? (low + high) / 2 : min(max(value, low), high)
	}
}
