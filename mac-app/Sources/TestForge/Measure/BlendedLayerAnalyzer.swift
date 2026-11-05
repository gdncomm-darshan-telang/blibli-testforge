import CoreGraphics
import Foundation

/// A layer's box found in a Color Blended Layers capture, in device points.
struct DetectedLayer: Equatable {
	let frame: CGRect

	/// Read from where the straight sides end; 0 for square corners. Approximate (about ±1 pt on a 3× screen).
	let cornerRadius: CGFloat
}

private struct VerticalSegment {
	let column: Int
	let top: Int
	let bottom: Int

	var length: Int {
		bottom - top
	}
}

private struct EdgeMaps {
	let width: Int
	let height: Int

	/// True where a row differs from the row above it; a layer's top or bottom side.
	let horizontal: [Bool]

	/// True where a column differs from the column left of it; a layer's left or right side.
	let vertical: [Bool]
}

private struct SidePair {
	let left: VerticalSegment
	let right: VerticalSegment
}

/// Color Blended Layers tints every layer, so boxes the accessibility tree leaves out show as straight colour boundaries.
/// A left side pairs only with the nearest right side of equal span, then needs a top and bottom side to count.
enum BlendedLayerAnalyzer {
	private static let colorThreshold = 40
	private static let minimumSidePoints: CGFloat = 6
	private static let minimumWidthPoints: CGFloat = 4
	private static let gapTolerancePoints: CGFloat = 3
	private static let spanTolerancePoints: CGFloat = 1.5
	private static let maxRadiusPoints: CGFloat = 32
	private static let sideCoverage = 0.8
	private static let duplicateOverlap: CGFloat = 0.9
	private static let arcCoverage = 0.6
	private static let arcWalkStart = 3

	/// Long sides may be partly covered (a floating button over a card's edge); both ends must still show.
	private static let occludedMinimumPoints: CGFloat = 30
	private static let occludedEndWindowPoints: CGFloat = 10
	private static let occludedCoverage = 0.5

	static func layers(in grid: PixelGrid) -> [DetectedLayer] {
		let maps = edgeMaps(grid: grid)
		let scale = grid.pixelsPerPoint
		let segments = verticalSegments(maps: maps, scale: scale)
		let bucketSize = max(Int(spanTolerancePoints * scale), 1)
		let buckets = Dictionary(grouping: segments) { $0.top / bucketSize }
		let found = segments.compactMap { left -> DetectedLayer? in
			let bucket = left.top / bucketSize
			let nearby = (bucket - 1...bucket + 1).flatMap { buckets[$0] ?? [] }
			let nearest = nearby
				.filter { isMatchingSpan(left: left, right: $0, scale: scale) }
				.min { $0.column < $1.column }
			if let nearest,
				let layer = confirmedLayer(pair: SidePair(left: left, right: nearest), maps: maps, scale: scale) {
				return layer
			}
			return occludedLayer(left: left, maps: maps, scale: scale)
		}
		return deduplicated(found + ThinBarDetector.bars(in: grid), screenSize: grid.pointSize)
	}

	private static func edgeMaps(grid: PixelGrid) -> EdgeMaps {
		let width = grid.width
		let height = grid.height
		var horizontal = [Bool](repeating: false, count: width * height)
		var vertical = [Bool](repeating: false, count: width * height)
		for row in 0..<height {
			for column in 0..<width {
				let color = grid.color(column: column, row: row)
				if row > 0 {
					horizontal[row * width + column] = color.difference(to: grid.color(column: column, row: row - 1)) > colorThreshold
				}
				if column > 0 {
					vertical[row * width + column] = color.difference(to: grid.color(column: column - 1, row: row)) > colorThreshold
				}
			}
		}
		return EdgeMaps(width: width, height: height, horizontal: horizontal, vertical: vertical)
	}

	/// Runs of vertical boundary per column, bridging short breaks where content touches a side; sorted left to right.
	private static func verticalSegments(maps: EdgeMaps, scale: CGFloat) -> [VerticalSegment] {
		let minimumLength = Int(minimumSidePoints * scale)
		let gapTolerance = Int(gapTolerancePoints * scale)
		var segments: [VerticalSegment] = []
		for column in 1..<maps.width {
			var runStart: Int?
			var lastHit = -gapTolerance - 1
			for row in 0..<maps.height {
				guard maps.vertical[row * maps.width + column] else {
					continue
				}
				if let start = runStart, row - lastHit > gapTolerance {
					if let found = segment(column: column, run: start...lastHit, minimumLength: minimumLength) {
						segments.append(found)
					}
					runStart = row
				} else if runStart == nil {
					runStart = row
				}
				lastHit = row
			}
			if let start = runStart {
				if let found = segment(column: column, run: start...lastHit, minimumLength: minimumLength) {
					segments.append(found)
				}
			}
		}
		return segments
	}

	private static func segment(column: Int, run: ClosedRange<Int>, minimumLength: Int) -> VerticalSegment? {
		guard run.upperBound - run.lowerBound >= minimumLength else {
			return nil
		}
		return VerticalSegment(column: column, top: run.lowerBound, bottom: run.upperBound)
	}

	private static func isMatchingSpan(left: VerticalSegment, right: VerticalSegment, scale: CGFloat) -> Bool {
		let tolerance = Int(spanTolerancePoints * scale)
		let minimumWidth = Int(minimumWidthPoints * scale)
		return right.column - left.column >= minimumWidth
			&& abs(right.top - left.top) <= tolerance
			&& abs(right.bottom - left.bottom) <= tolerance
	}

	/// For a long left side with no clean partner: the nearest column whose edge shows at both ends and over half the span.
	private static func occludedLayer(left: VerticalSegment, maps: EdgeMaps, scale: CGFloat) -> DetectedLayer? {
		guard CGFloat(left.length) >= occludedMinimumPoints * scale else {
			return nil
		}
		let endWindow = Int(occludedEndWindowPoints * scale)
		let firstColumn = left.column + Int(minimumWidthPoints * scale)
		guard firstColumn < maps.width - 1 else {
			return nil
		}
		for column in firstColumn..<(maps.width - 1) {
			let hasTop = hasVerticalEdge(column: column, rows: left.top...(left.top + endWindow), maps: maps)
			let hasBottom = hasVerticalEdge(column: column, rows: (left.bottom - endWindow)...left.bottom, maps: maps)
			guard hasTop,
				hasBottom,
				verticalCoverage(column: column, rows: left.top...left.bottom, maps: maps) >= occludedCoverage
			else {
				continue
			}
			let right = VerticalSegment(column: column, top: left.top, bottom: left.bottom)
			return confirmedLayer(pair: SidePair(left: left, right: right), maps: maps, scale: scale)
		}
		return nil
	}

	private static func hasVerticalEdge(column: Int, rows: ClosedRange<Int>, maps: EdgeMaps) -> Bool {
		rows.contains { row in
			row >= 0 && row < maps.height && (column...column + 1).contains { maps.vertical[row * maps.width + $0] }
		}
	}

	private static func verticalCoverage(column: Int, rows: ClosedRange<Int>, maps: EdgeMaps) -> Double {
		let hits = rows.filter { row in
			row >= 0 && row < maps.height && (column...column + 1).contains { maps.vertical[row * maps.width + $0] }
		}.count
		return Double(hits) / Double(max(rows.count, 1))
	}

	/// Finds the top and bottom sides; for a rounded box they sit one radius beyond where the straight sides end.
	private static func confirmedLayer(pair: SidePair, maps: EdgeMaps, scale: CGFloat) -> DetectedLayer? {
		let leftColumn = pair.left.column
		let rightColumn = pair.right.column
		let top = min(pair.left.top, pair.right.top)
		let bottom = max(pair.left.bottom, pair.right.bottom)
		let maxRadius = min(Int(maxRadiusPoints * scale), (rightColumn - leftColumn) / 2)
		let topInset = (0...maxRadius).first { inset in
			let row = top - inset
			return row > 0 && coverage(row: row, from: leftColumn + inset, to: rightColumn - inset, maps: maps) >= sideCoverage
		}
		let bottomInset = (0...maxRadius).first { inset in
			let row = bottom + 1 + inset
			return row < maps.height && coverage(row: row, from: leftColumn + inset, to: rightColumn - inset, maps: maps) >= sideCoverage
		}
		guard let topInset,
			let bottomInset,
			hasCorners(pair: pair, insets: (topInset, bottomInset), maps: maps)
		else {
			return nil
		}
		let frame = CGRect(
			x: CGFloat(leftColumn) / scale,
			y: CGFloat(top - topInset) / scale,
			width: CGFloat(rightColumn - leftColumn) / scale,
			height: CGFloat(bottom + 1 + bottomInset - (top - topInset)) / scale
		)
		let pixelFrame = PixelBox(left: leftColumn, top: top - topInset, right: rightColumn, bottom: bottom + 1 + bottomInset)
		let radius = arcRadius(pixelFrame: pixelFrame, maps: maps) / scale
		return DetectedLayer(frame: frame, cornerRadius: radius)
	}

	/// Walks 45° in from each corner to the first edge pixel, the arc, at r × (1 − 1/√2); the median resists one hidden corner.
	/// The walk starts a few pixels in so the straight sides' anti-aliased edges at the corner itself aren't taken for the arc.
	private static func arcRadius(pixelFrame: PixelBox, maps: EdgeMaps) -> CGFloat {
		let maxWalk = min(pixelFrame.right - pixelFrame.left, pixelFrame.bottom - pixelFrame.top) / 2
		let corners = [
			(column: pixelFrame.left, row: pixelFrame.top, stepX: 1, stepY: 1),
			(column: pixelFrame.right - 1, row: pixelFrame.top, stepX: -1, stepY: 1),
			(column: pixelFrame.left, row: pixelFrame.bottom - 1, stepX: 1, stepY: -1),
			(column: pixelFrame.right - 1, row: pixelFrame.bottom - 1, stepX: -1, stepY: -1)
		]
		guard maxWalk > arcWalkStart else {
			return 0
		}
		let cornerRadii = corners.compactMap { corner -> CGFloat? in
			let walk = (arcWalkStart..<maxWalk).first { distance in
				isEdgeNear(column: corner.column + corner.stepX * distance, row: corner.row + corner.stepY * distance, maps: maps)
			}
			return walk.map { CGFloat($0) / (1 - 1 / 2.0.squareRoot()) }
		}
		let radii = cornerRadii.sorted()
		return radii[safe: radii.count / 2] ?? 0
	}

	/// A rounded box shows its arc in the corner square; text strokes paired with a label's top and bottom don't.
	private static func hasCorners(pair: SidePair, insets: (top: Int, bottom: Int), maps: EdgeMaps) -> Bool {
		let left = pair.left.column
		let right = pair.right.column
		let top = min(pair.left.top, pair.right.top)
		let bottom = max(pair.left.bottom, pair.right.bottom) + 1
		let corners = [
			(centerX: left + insets.top, centerY: top, radius: insets.top, signX: -1, signY: -1),
			(centerX: right - insets.top, centerY: top, radius: insets.top, signX: 1, signY: -1),
			(centerX: left + insets.bottom, centerY: bottom, radius: insets.bottom, signX: -1, signY: 1),
			(centerX: right - insets.bottom, centerY: bottom, radius: insets.bottom, signX: 1, signY: 1)
		]
		return corners.allSatisfy { corner in
			guard corner.radius > 1 else {
				return true
			}
			let angles = stride(from: 0.2, through: 1.37, by: 0.15)
			let hits = angles.filter { angle in
				let column = corner.centerX + corner.signX * Int((Double(corner.radius) * cos(angle)).rounded())
				let row = corner.centerY + corner.signY * Int((Double(corner.radius) * sin(angle)).rounded())
				return isEdgeNear(column: column, row: row, maps: maps)
			}
			return Double(hits.count) >= Double(angles.underestimatedCount) * arcCoverage
		}
	}

	private static func isEdgeNear(column: Int, row: Int, maps: EdgeMaps) -> Bool {
		for rowOffset in -1...1 {
			for columnOffset in -1...1 {
				let probeRow = row + rowOffset
				let probeColumn = column + columnOffset
				guard probeRow >= 0,
					probeRow < maps.height,
					probeColumn >= 0,
					probeColumn < maps.width
				else {
					continue
				}
				let index = probeRow * maps.width + probeColumn
				if maps.horizontal[index] || maps.vertical[index] {
					return true
				}
			}
		}
		return false
	}

	/// Share of the row's span with a horizontal boundary on it or one pixel either side (anti-aliasing).
	private static func coverage(row: Int, from startColumn: Int, to endColumn: Int, maps: EdgeMaps) -> Double {
		guard endColumn > startColumn else {
			return 0
		}
		var hits = 0
		for column in startColumn..<endColumn {
			let rows = [row - 1, row, row + 1].filter { $0 >= 0 && $0 < maps.height }
			if rows.contains(where: { maps.horizontal[$0 * maps.width + column] }) {
				hits += 1
			}
		}
		return Double(hits) / Double(endColumn - startColumn)
	}

	/// Anti-aliased sides show up one pixel apart, so near-identical boxes collapse to one; the full screen is dropped.
	private static func deduplicated(_ layers: [DetectedLayer], screenSize: CGSize) -> [DetectedLayer] {
		var kept: [DetectedLayer] = []
		for layer in layers {
			let isFullScreen = layer.frame.width >= screenSize.width * 0.98 && layer.frame.height >= screenSize.height * 0.98
			let isDuplicate = kept.contains { overlapShare(layer.frame, $0.frame) >= duplicateOverlap }
			if !isFullScreen && !isDuplicate {
				kept.append(layer)
			}
		}
		return kept
	}

	private static func overlapShare(_ first: CGRect, _ second: CGRect) -> CGFloat {
		let shared = first.intersection(second)
		guard !shared.isNull else {
			return 0
		}
		let union = first.width * first.height + second.width * second.height - shared.width * shared.height
		return union > 0 ? shared.width * shared.height / union : 0
	}
}

/// A box in whole pixels; right and bottom are exclusive.
private struct PixelBox {
	let left: Int
	let top: Int
	let right: Int
	let bottom: Int
}
