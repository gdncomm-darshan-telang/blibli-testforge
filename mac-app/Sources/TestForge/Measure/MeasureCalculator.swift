import CoreGraphics
import Foundation

enum MeasuredElementSource: Equatable {
	case accessibility

	/// A layer box found in the Color Blended Layers capture; no identifier, label or attributes.
	case layerColors
}

struct MeasuredElement: Equatable, Identifiable {
	let id: Int
	let identifier: String
	let role: String
	let label: String

	/// In device points, read from the Simulator and scaled back, so the numbers match the layout code.
	let frame: CGRect

	let path: [Int]
	let parentId: Int?
	let childCount: Int
	var source: MeasuredElementSource = .accessibility

	/// From the layer capture's corner curve; nil when no layer box matched this element.
	var cornerRadius: CGFloat?

	var title: String {
		if source == .layerColors {
			return String(localized: "View without id")
		}
		let shortRole = role.replacingOccurrences(of: "AX", with: "")
		if !identifier.isEmpty {
			return identifier
		}
		return label.isEmpty ? shortRole : "\(shortRole) “\(label)”"
	}
}

enum MeasureEdge: String, CaseIterable {
	case top
	case leading
	case bottom
	case trailing
}

struct MeasureGap: Equatable, Identifiable {
	let edge: MeasureEdge
	let distance: CGFloat
	let start: CGPoint
	let end: CGPoint

	/// What the gap runs to: a neighbour's title, or the container's.
	let toTitle: String

	var id: MeasureEdge {
		edge
	}
}

struct MeasureContainer: Equatable {
	let title: String
	let frame: CGRect

	/// Edges found in the screenshot; the rest belong to the structural container named by `structuralTitle`.
	let visibleEdges: Set<MeasureEdge>

	let structuralTitle: String

	init(title: String, frame: CGRect) {
		self.title = title
		self.frame = frame
		visibleEdges = []
		structuralTitle = title
	}

	/// Narrows a structural container to the card seen in the pixels, keeping its title for edges the pixels didn't show.
	init(visible: VisibleContainer, structural: MeasureContainer) {
		title = String(localized: "Visible container")
		frame = visible.frame
		visibleEdges = visible.detectedEdges
		structuralTitle = structural.title
	}

	func title(for edge: MeasureEdge) -> String {
		visibleEdges.contains(edge) ? title : structuralTitle
	}
}

private struct GapContext {
	let element: MeasuredElement
	let neighbours: [MeasuredElement]
	let container: MeasureContainer
}

/// Distances in the style of a design tool: from each edge to the nearest neighbour facing it, else to the container.
enum MeasureCalculator {
	/// Half a point of rounding is noise from the Simulator's scaled coordinates, not a real offset.
	static let roundingStep: CGFloat = 0.5

	static func rounded(_ value: CGFloat) -> CGFloat {
		(value / roundingStep).rounded() * roundingStep
	}

	/// Share of an element that must be on screen to be shown; carousels report cards scrolled off to the side.
	static let minimumVisibleShare: CGFloat = 0.5

	/// Elements a reviewer can pick: mostly on screen, smaller than the screen, one per identical frame.
	static func selectable(elements: [MeasuredElement], screenSize: CGSize) -> [MeasuredElement] {
		let screenRect = CGRect(origin: .zero, size: screenSize)
		var seenFrames = Set<String>()
		return elements.filter { element in
			let frame = element.frame
			let visibleArea = screenRect.intersection(frame).area
			guard frame.width >= 1,
				frame.height >= 1,
				visibleArea >= frame.area * minimumVisibleShare,
				frame.size != screenSize
			else {
				return false
			}
			let key = "\(rounded(frame.minX)),\(rounded(frame.minY)),\(rounded(frame.width)),\(rounded(frame.height))"
			return seenFrames.insert(key).inserted
		}
	}

	/// The smallest other element that fully contains this one, else the screen.
	static func container(of element: MeasuredElement, in elements: [MeasuredElement], screenSize: CGSize) -> MeasureContainer {
		let candidates = elements.filter { candidate in
			candidate.id != element.id && candidate.frame.contains(element.frame) && candidate.frame != element.frame
		}
		guard let smallest = candidates.min(by: { $0.frame.area < $1.frame.area }) else {
			return MeasureContainer(title: String(localized: "Screen"), frame: CGRect(origin: .zero, size: screenSize))
		}
		return MeasureContainer(title: smallest.title, frame: smallest.frame)
	}

	/// Parents up the tree, outermost first; follows `parentId`, so it works on the unfiltered element list.
	static func ancestors(of element: MeasuredElement, in elements: [MeasuredElement]) -> [MeasuredElement] {
		let byId = Dictionary(uniqueKeysWithValues: elements.map { ($0.id, $0) })
		var chain: [MeasuredElement] = []
		var parentId = element.parentId
		while let currentId = parentId,
			let parent = byId[currentId] {
			chain.append(parent)
			parentId = parent.parentId
		}
		return chain.reversed()
	}

	/// Only neighbours inside the container count, so nothing outside a card is measured to.
	static func gaps(for element: MeasuredElement, in elements: [MeasuredElement], container enclosing: MeasureContainer) -> [MeasureGap] {
		let neighbours = elements.filter { candidate in
			candidate.id != element.id && enclosing.frame.contains(candidate.frame) && !candidate.frame.intersects(element.frame)
		}
		let context = GapContext(element: element, neighbours: neighbours, container: enclosing)
		return MeasureEdge.allCases.map { edge in
			gap(edge: edge, context: context)
		}
	}

	private static func gap(edge: MeasureEdge, context: GapContext) -> MeasureGap {
		let frame = context.element.frame
		let container = context.container
		let facing = context.neighbours.compactMap { neighbour -> (distance: CGFloat, title: String)? in
			guard let neighbourDistance = distance(from: frame, to: neighbour.frame, edge: edge) else {
				return nil
			}
			return (neighbourDistance, neighbour.title)
		}
		let nearest = facing.min { $0.distance < $1.distance }
		let containerDistance = insetDistance(of: frame, in: container.frame, edge: edge)
		let gapDistance = nearest?.distance ?? containerDistance
		let toTitle = nearest?.title ?? container.title(for: edge)
		let gapLine = line(from: frame, edge: edge, length: gapDistance)
		return MeasureGap(edge: edge, distance: gapDistance, start: gapLine.start, end: gapLine.end, toTitle: toTitle)
	}

	/// Distance to a neighbour on the given side whose span overlaps the element's, else nil.
	private static func distance(from frame: CGRect, to other: CGRect, edge: MeasureEdge) -> CGFloat? {
		let isHorizontalOverlap = other.maxX > frame.minX && other.minX < frame.maxX
		let isVerticalOverlap = other.maxY > frame.minY && other.minY < frame.maxY
		switch edge {
			case .top:
				return isHorizontalOverlap && other.maxY <= frame.minY ? frame.minY - other.maxY : nil
			case .bottom:
				return isHorizontalOverlap && other.minY >= frame.maxY ? other.minY - frame.maxY : nil
			case .leading:
				return isVerticalOverlap && other.maxX <= frame.minX ? frame.minX - other.maxX : nil
			case .trailing:
				return isVerticalOverlap && other.minX >= frame.maxX ? other.minX - frame.maxX : nil
		}
	}

	private static func insetDistance(of frame: CGRect, in container: CGRect, edge: MeasureEdge) -> CGFloat {
		switch edge {
			case .top:
				return frame.minY - container.minY
			case .bottom:
				return container.maxY - frame.maxY
			case .leading:
				return frame.minX - container.minX
			case .trailing:
				return container.maxX - frame.maxX
		}
	}

	private static func line(from frame: CGRect, edge: MeasureEdge, length: CGFloat) -> (start: CGPoint, end: CGPoint) {
		switch edge {
			case .top:
				let start = CGPoint(x: frame.midX, y: frame.minY)
				return (start, CGPoint(x: start.x, y: start.y - length))
			case .bottom:
				let start = CGPoint(x: frame.midX, y: frame.maxY)
				return (start, CGPoint(x: start.x, y: start.y + length))
			case .leading:
				let start = CGPoint(x: frame.minX, y: frame.midY)
				return (start, CGPoint(x: start.x - length, y: start.y))
			case .trailing:
				let start = CGPoint(x: frame.maxX, y: frame.midY)
				return (start, CGPoint(x: start.x + length, y: start.y))
		}
	}
}

/// One parent around the selected element with the inset to each of its edges.
struct MeasureEnclosure: Equatable, Identifiable {
	let title: String
	let frame: CGRect
	let insets: [MeasureEdge: CGFloat]

	var id: String {
		"\(title)|\(frame.minX),\(frame.minY),\(frame.width),\(frame.height)"
	}
}

/// What the pointer is over while an element is selected, and the distances between the two.
struct MeasureComparison: Equatable {
	let title: String
	let frame: CGRect
	let gaps: [MeasureGap]
}

/// Relations of one element to everything around it: every parent's insets, and distances to any other element.
enum MeasureRelations {
	private static let maximumEnclosures = 5

	/// Innermost first, ending with the screen; parents with the same frame are listed once.
	static func enclosures(of element: MeasuredElement, extra: [MeasureContainer], context: MeasureRelationContext) -> [MeasureEnclosure] {
		let screen = CGRect(origin: .zero, size: context.screenSize)
		let containing = context.elements
			.filter { $0.id != element.id && $0.frame.contains(element.frame) && $0.frame != element.frame }
			.map { MeasureContainer(title: $0.title, frame: $0.frame) }
		let candidates = (containing + extra + [MeasureContainer(title: String(localized: "Screen"), frame: screen)])
			.sorted { $0.frame.area < $1.frame.area }
		var seenFrames = Set<String>()
		let unique = candidates.filter { container in
			let frame = container.frame
			let key = "\(MeasureCalculator.rounded(frame.minX)),\(MeasureCalculator.rounded(frame.minY)),\(MeasureCalculator.rounded(frame.width))"
			return seenFrames.insert(key).inserted
		}
		return unique.prefix(maximumEnclosures).map { container in
			MeasureEnclosure(title: container.title, frame: container.frame, insets: insets(of: element.frame, in: container.frame))
		}
	}

	/// Insets when one contains the other, else the gaps on the sides where they don't overlap.
	static func comparison(of frame: CGRect, with other: MeasureContainer) -> MeasureComparison {
		let target = other.frame
		let gaps: [MeasureGap]
		if target.contains(frame) {
			gaps = MeasureEdge.allCases.map { edge in
				insetGap(inner: frame, outer: target, edge: edge, title: other.title)
			}
		} else if frame.contains(target) {
			gaps = MeasureEdge.allCases.map { edge in
				insetGap(inner: target, outer: frame, edge: edge, title: other.title)
			}
		} else {
			gaps = separationGaps(from: frame, to: target, title: other.title)
		}
		return MeasureComparison(title: other.title, frame: target, gaps: gaps)
	}

	private static func insets(of frame: CGRect, in container: CGRect) -> [MeasureEdge: CGFloat] {
		[
			.top: frame.minY - container.minY,
			.leading: frame.minX - container.minX,
			.bottom: container.maxY - frame.maxY,
			.trailing: container.maxX - frame.maxX
		]
	}

	private static func insetGap(inner: CGRect, outer: CGRect, edge: MeasureEdge, title: String) -> MeasureGap {
		let start: CGPoint
		let end: CGPoint
		switch edge {
			case .top:
				start = CGPoint(x: inner.midX, y: inner.minY)
				end = CGPoint(x: inner.midX, y: outer.minY)
			case .bottom:
				start = CGPoint(x: inner.midX, y: inner.maxY)
				end = CGPoint(x: inner.midX, y: outer.maxY)
			case .leading:
				start = CGPoint(x: inner.minX, y: inner.midY)
				end = CGPoint(x: outer.minX, y: inner.midY)
			case .trailing:
				start = CGPoint(x: inner.maxX, y: inner.midY)
				end = CGPoint(x: outer.maxX, y: inner.midY)
		}
		let distance = abs(end.x - start.x) + abs(end.y - start.y)
		return MeasureGap(edge: edge, distance: distance, start: start, end: end, toTitle: title)
	}

	/// The line sits in the middle of the span both share, or on the selected element's centre when they share none.
	private static func separationGaps(from frame: CGRect, to target: CGRect, title: String) -> [MeasureGap] {
		let sharedMinY = max(frame.minY, target.minY)
		let sharedMaxY = min(frame.maxY, target.maxY)
		let lineY = sharedMinY < sharedMaxY ? (sharedMinY + sharedMaxY) / 2 : frame.midY
		let sharedMinX = max(frame.minX, target.minX)
		let sharedMaxX = min(frame.maxX, target.maxX)
		let lineX = sharedMinX < sharedMaxX ? (sharedMinX + sharedMaxX) / 2 : frame.midX
		var gaps: [MeasureGap] = []
		if target.minX >= frame.maxX {
			gaps.append(gap(edge: .trailing, from: CGPoint(x: frame.maxX, y: lineY), to: CGPoint(x: target.minX, y: lineY), title: title))
		} else if target.maxX <= frame.minX {
			gaps.append(gap(edge: .leading, from: CGPoint(x: frame.minX, y: lineY), to: CGPoint(x: target.maxX, y: lineY), title: title))
		}
		if target.minY >= frame.maxY {
			gaps.append(gap(edge: .bottom, from: CGPoint(x: lineX, y: frame.maxY), to: CGPoint(x: lineX, y: target.minY), title: title))
		} else if target.maxY <= frame.minY {
			gaps.append(gap(edge: .top, from: CGPoint(x: lineX, y: frame.minY), to: CGPoint(x: lineX, y: target.maxY), title: title))
		}
		return gaps
	}

	private static func gap(edge: MeasureEdge, from start: CGPoint, to end: CGPoint, title: String) -> MeasureGap {
		let distance = abs(end.x - start.x) + abs(end.y - start.y)
		return MeasureGap(edge: edge, distance: distance, start: start, end: end, toTitle: title)
	}
}

struct MeasureRelationContext {
	let elements: [MeasuredElement]
	let screenSize: CGSize
}

/// Spacing as the design system writes it (D-123): 0, 1, 2, 4, then multiples of 4 — 9.17 → 8, 13.4 → 12, 28 → 28, 40.7 → 40.
/// Never a fraction; ties go to the larger value.
enum MeasureSpacing {
	static func display(_ distance: CGFloat, pixelsPerPoint: CGFloat) -> CGFloat {
		let scale = max(pixelsPerPoint, 1)
		let onPixelGrid = (distance * scale).rounded() / scale
		let magnitude = abs(onPixelGrid)
		let snapped = snapToScale(magnitude)
		return onPixelGrid < 0 ? -snapped : snapped
	}

	static func snapToScale(_ value: CGFloat) -> CGFloat {
		let steps = TestForgeConstants.Measure.spacingScale
		guard let largest = steps.last,
			value <= largest
		else {
			let step = TestForgeConstants.Measure.largeSpacingStep
			return (value / step).rounded(.toNearestOrAwayFromZero) * step
		}
		return steps.min { lhs, rhs in
			let lhsDistance = abs(lhs - value)
			let rhsDistance = abs(rhs - value)
			return lhsDistance == rhsDistance ? lhs > rhs : lhsDistance < rhsDistance
		} ?? value.rounded()
	}
}

extension MeasureGap {
	func displayed(pixelsPerPoint: CGFloat) -> MeasureGap {
		MeasureGap(edge: edge, distance: MeasureSpacing.display(distance, pixelsPerPoint: pixelsPerPoint), start: start, end: end, toTitle: toTitle)
	}
}

extension MeasureEnclosure {
	func displayed(pixelsPerPoint: CGFloat) -> MeasureEnclosure {
		let roundedInsets = insets.mapValues { MeasureSpacing.display($0, pixelsPerPoint: pixelsPerPoint) }
		return MeasureEnclosure(title: title, frame: frame, insets: roundedInsets)
	}
}

extension MeasureComparison {
	func displayed(pixelsPerPoint: CGFloat) -> MeasureComparison {
		let roundedGaps = gaps.map { $0.displayed(pixelsPerPoint: pixelsPerPoint) }
		return MeasureComparison(title: title, frame: frame, gaps: roundedGaps)
	}
}
