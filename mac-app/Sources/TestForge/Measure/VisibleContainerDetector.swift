import CoreGraphics
import Foundation

/// A container seen in the pixels (a card, a sheet) that the accessibility tree doesn't report.
struct VisibleContainer: Equatable {
	let frame: CGRect

	/// Edges actually found in the pixels; the others fall back to the structural container.
	let detectedEdges: Set<MeasureEdge>

	/// Estimated from the corner curve, so it's approximate (about ±1 pt on a 3× screen).
	let cornerRadius: CGFloat?
}

private struct EdgeScan {
	let edge: MeasureEdge
	let starts: [CGPoint]
	let background: PixelColor
	let maxDistance: CGFloat
}

private struct DetectionInput {
	let element: CGRect
	let bounds: CGRect
	let grid: PixelGrid
}

private struct CornerSpec {
	let edges: (MeasureEdge, MeasureEdge)
	let origin: CGPoint
	let direction: CGPoint
}

private struct CornerProbe {
	let origin: CGPoint
	let direction: CGPoint
	let cardColor: PixelColor
	let limit: CGFloat
}

/// Walks out from an element's edges to the first straight colour boundary that every scan line meets.
/// A candidate only counts when the boundary runs along the whole side of the box it makes, so text and sibling cards are skipped.
enum VisibleContainerDetector {
	private static let lineCount = 7
	private static let sideSampleCount = 15
	private static let colorThreshold = 24
	private static let startOffset: CGFloat = 1
	private static let holdLength: CGFloat = 2
	private static let edgeTolerance: CGFloat = 1
	private static let minimumEdgeCount = 2
	private static let maxRounds = 4_000

	/// Share of side samples that must show the boundary; content may touch a card's edge in a few places.
	private static let sideAgreement = 0.85

	/// `bounds` is the structural container (the screen when nothing encloses the element).
	static func detect(around element: CGRect, within bounds: CGRect, grid: PixelGrid) -> VisibleContainer? {
		let input = DetectionInput(element: element, bounds: bounds, grid: grid)
		let scans = MeasureEdge.allCases.compactMap { makeScan(edge: $0, input: input) }
		var distances: [MeasureEdge: CGFloat] = [:]
		for scan in scans {
			distances[scan.edge] = nextBoundary(scan: scan, from: startOffset, grid: grid)
		}
		for _ in 0..<maxRounds {
			let frame = containerFrame(distances: distances, input: input)
			let failing = scans.filter { scan in
				distances[scan.edge] != nil && !isStraightSide(scan: scan, frame: frame, grid: grid)
			}
			guard !failing.isEmpty else {
				break
			}
			for scan in failing {
				let distance = distances[scan.edge] ?? scan.maxDistance
				distances[scan.edge] = nextBoundary(scan: scan, from: distance + 1 / grid.pixelsPerPoint, grid: grid)
			}
		}
		guard distances.count >= minimumEdgeCount else {
			return nil
		}
		let frame = containerFrame(distances: distances, input: input)
		let backgrounds = Dictionary(uniqueKeysWithValues: scans.map { ($0.edge, $0.background) })
		let radius = cornerRadius(of: frame, edges: Set(distances.keys), backgrounds: backgrounds, grid: grid)
		return VisibleContainer(frame: frame, detectedEdges: Set(distances.keys), cornerRadius: radius)
	}

	private static func containerFrame(distances: [MeasureEdge: CGFloat], input: DetectionInput) -> CGRect {
		let element = input.element
		let bounds = input.bounds
		let minX = distances[.leading].map { element.minX - $0 } ?? bounds.minX
		let minY = distances[.top].map { element.minY - $0 } ?? bounds.minY
		let maxX = distances[.trailing].map { element.maxX + $0 } ?? bounds.maxX
		let maxY = distances[.bottom].map { element.maxY + $0 } ?? bounds.maxY
		return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
	}

	/// The colour just outside the element must be one flat colour along the edge, else there's no card to find.
	private static func makeScan(edge: MeasureEdge, input: DetectionInput) -> EdgeScan? {
		let element = input.element
		let bounds = input.bounds
		let starts = startPoints(edge: edge, frame: element)
		let colors = starts.compactMap { input.grid.color(at: $0) }
		guard colors.count == starts.count,
			let background = colors[safe: colors.count / 2],
			colors.allSatisfy({ $0.difference(to: background) <= colorThreshold })
		else {
			return nil
		}
		let maxDistance: CGFloat
		switch edge {
			case .top:
				maxDistance = element.minY - bounds.minY
			case .bottom:
				maxDistance = bounds.maxY - element.maxY
			case .leading:
				maxDistance = element.minX - bounds.minX
			case .trailing:
				maxDistance = bounds.maxX - element.maxX
		}
		return EdgeScan(edge: edge, starts: starts, background: background, maxDistance: maxDistance)
	}

	private static func startPoints(edge: MeasureEdge, frame: CGRect) -> [CGPoint] {
		let insetFraction: CGFloat = 0.1
		return (0..<lineCount).map { index in
			let fraction = insetFraction + (1 - 2 * insetFraction) * CGFloat(index) / CGFloat(lineCount - 1)
			switch edge {
				case .top:
					return CGPoint(x: frame.minX + frame.width * fraction, y: frame.minY - startOffset)
				case .bottom:
					return CGPoint(x: frame.minX + frame.width * fraction, y: frame.maxY + startOffset)
				case .leading:
					return CGPoint(x: frame.minX - startOffset, y: frame.minY + frame.height * fraction)
				case .trailing:
					return CGPoint(x: frame.maxX + startOffset, y: frame.minY + frame.height * fraction)
			}
		}
	}

	/// The next distance, from `start`, where every line leaves the background colour and stays off it for `holdLength`.
	/// Answers the boundary between the last background pixel and the first one past it, half a pixel back.
	private static func nextBoundary(scan: EdgeScan, from start: CGFloat, grid: PixelGrid) -> CGFloat? {
		let step = 1 / grid.pixelsPerPoint
		var distance = start
		while distance + holdLength <= scan.maxDistance + edgeTolerance {
			let isBoundary = scan.starts.allSatisfy { lineStart in
				let firstPoint = moved(lineStart, edge: scan.edge, by: distance - startOffset)
				return holdsOffBackground(from: firstPoint, scan: scan, grid: grid)
			}
			if isBoundary {
				return max(distance - step / 2, 0)
			}
			distance += step
		}
		return nil
	}

	private static func holdsOffBackground(from point: CGPoint, scan: EdgeScan, grid: PixelGrid) -> Bool {
		let step = 1 / grid.pixelsPerPoint
		var offset: CGFloat = 0
		while offset <= holdLength {
			let probe = moved(point, edge: scan.edge, by: offset)
			guard let color = grid.color(at: probe),
				color.difference(to: scan.background) > colorThreshold
			else {
				return false
			}
			offset += step
		}
		return true
	}

	/// Along the whole side (corners left out), the background must end exactly here, against one flat outside colour.
	private static func isStraightSide(scan: EdgeScan, frame: CGRect, grid: PixelGrid) -> Bool {
		let points = sidePoints(edge: scan.edge, frame: frame)
		let outsideColors = points.compactMap { point -> PixelColor? in
			let inside = moved(point, edge: scan.edge, by: -startOffset)
			let outside = moved(point, edge: scan.edge, by: startOffset)
			guard let insideColor = grid.color(at: inside),
				let outsideColor = grid.color(at: outside),
				insideColor.difference(to: scan.background) <= colorThreshold,
				outsideColor.difference(to: scan.background) > colorThreshold
			else {
				return nil
			}
			return outsideColor
		}
		let required = Double(points.count) * sideAgreement
		guard Double(outsideColors.count) >= required,
			let outsideColor = outsideColors[safe: outsideColors.count / 2]
		else {
			return false
		}
		let uniformCount = outsideColors.filter { $0.difference(to: outsideColor) <= colorThreshold }.count
		return Double(uniformCount) >= required
	}

	/// Points on the boundary line itself, skipping a quarter at each end where a rounded corner bends away.
	private static func sidePoints(edge: MeasureEdge, frame: CGRect) -> [CGPoint] {
		let insetFraction: CGFloat = 0.25
		return (0..<sideSampleCount).map { index in
			let fraction = insetFraction + (1 - 2 * insetFraction) * CGFloat(index) / CGFloat(sideSampleCount - 1)
			switch edge {
				case .top:
					return CGPoint(x: frame.minX + frame.width * fraction, y: frame.minY)
				case .bottom:
					return CGPoint(x: frame.minX + frame.width * fraction, y: frame.maxY)
				case .leading:
					return CGPoint(x: frame.minX, y: frame.minY + frame.height * fraction)
				case .trailing:
					return CGPoint(x: frame.maxX, y: frame.minY + frame.height * fraction)
			}
		}
	}

	private static func moved(_ point: CGPoint, edge: MeasureEdge, by distance: CGFloat) -> CGPoint {
		switch edge {
			case .top:
				return CGPoint(x: point.x, y: point.y - distance)
			case .bottom:
				return CGPoint(x: point.x, y: point.y + distance)
			case .leading:
				return CGPoint(x: point.x - distance, y: point.y)
			case .trailing:
				return CGPoint(x: point.x + distance, y: point.y)
		}
	}

	/// Averages the corners whose two edges were found; on a 45° walk the card colour starts at r × (1 − 1/√2).
	private static func cornerRadius(
		of frame: CGRect,
		edges: Set<MeasureEdge>,
		backgrounds: [MeasureEdge: PixelColor],
		grid: PixelGrid
	) -> CGFloat? {
		let limit = min(frame.width, frame.height) / 2
		let corners = [
			CornerSpec(edges: (.top, .leading), origin: CGPoint(x: frame.minX, y: frame.minY), direction: CGPoint(x: 1, y: 1)),
			CornerSpec(edges: (.top, .trailing), origin: CGPoint(x: frame.maxX, y: frame.minY), direction: CGPoint(x: -1, y: 1)),
			CornerSpec(edges: (.bottom, .leading), origin: CGPoint(x: frame.minX, y: frame.maxY), direction: CGPoint(x: 1, y: -1)),
			CornerSpec(edges: (.bottom, .trailing), origin: CGPoint(x: frame.maxX, y: frame.maxY), direction: CGPoint(x: -1, y: -1))
		]
		let radii = corners.compactMap { corner -> CGFloat? in
			guard edges.contains(corner.edges.0),
				edges.contains(corner.edges.1),
				let cardColor = backgrounds[corner.edges.0]
			else {
				return nil
			}
			let probe = CornerProbe(origin: corner.origin, direction: corner.direction, cardColor: cardColor, limit: limit)
			return diagonalRadius(probe: probe, grid: grid)
		}
		guard !radii.isEmpty else {
			return nil
		}
		return radii.reduce(0, +) / CGFloat(radii.count)
	}

	private static func diagonalRadius(probe: CornerProbe, grid: PixelGrid) -> CGFloat? {
		let step = 1 / grid.pixelsPerPoint
		let inset = step / 2
		var travel: CGFloat = 0
		while travel < probe.limit {
			let reach = travel + inset
			let point = CGPoint(x: probe.origin.x + probe.direction.x * reach, y: probe.origin.y + probe.direction.y * reach)
			if let color = grid.color(at: point),
				color.difference(to: probe.cardColor) <= colorThreshold {
				return max(travel - inset, 0) / (1 - 1 / 2.0.squareRoot())
			}
			travel += step
		}
		return nil
	}
}
