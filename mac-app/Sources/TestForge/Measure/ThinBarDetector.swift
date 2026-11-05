import CoreGraphics
import Foundation

/// Bars too short for side pairing (under 6 pt tall): pager pills, tab underlines, progress tracks.
/// A bar is a flat fill between a top and bottom boundary of the same span, with a flat background above and below.
enum ThinBarDetector {
	private static let colorThreshold = 40
	private static let flatThreshold = 24
	private static let minimumWidthPoints: CGFloat = 4
	private static let minimumHeightPoints: CGFloat = 1
	private static let maximumHeightPoints: CGFloat = 6
	private static let edgeCoverage = 0.8
	private static let interiorEdgeLimit = 0.2

	static func bars(in grid: PixelGrid) -> [DetectedLayer] {
		let scale = grid.pixelsPerPoint
		let minimumWidth = max(Int(minimumWidthPoints * scale), 2)
		var bars: [DetectedLayer] = []
		for row in 1..<grid.height {
			for run in edgeRuns(row: row, grid: grid, minimumWidth: minimumWidth) {
				if let bar = bar(top: row, run: run, grid: grid) {
					bars.append(bar)
				}
			}
		}
		return bars
	}

	private static func isEdge(column: Int, row: Int, grid: PixelGrid) -> Bool {
		let above = grid.color(column: column, row: row - 1)
		return grid.color(column: column, row: row).difference(to: above) > colorThreshold
	}

	private static func edgeRuns(row: Int, grid: PixelGrid, minimumWidth: Int) -> [ClosedRange<Int>] {
		var runs: [ClosedRange<Int>] = []
		var runStart: Int?
		for column in 0...grid.width {
			let isBoundary = column < grid.width && isEdge(column: column, row: row, grid: grid)
			if isBoundary {
				runStart = runStart ?? column
			} else if let start = runStart {
				if column - start >= minimumWidth {
					runs.append(start...(column - 1))
				}
				runStart = nil
			}
		}
		return runs
	}

	/// The first row below with a boundary over the same span closes the bar; a boundary inside it means it isn't flat.
	private static func bar(top: Int, run: ClosedRange<Int>, grid: PixelGrid) -> DetectedLayer? {
		let scale = grid.pixelsPerPoint
		let minimumHeight = max(Int(minimumHeightPoints * scale), 2)
		let maximumHeight = Int(maximumHeightPoints * scale)
		for height in 1...maximumHeight {
			let bottom = top + height
			guard bottom < grid.height else {
				return nil
			}
			let inset = min(height / 2, run.count / 4)
			let span = (run.lowerBound + inset)...(run.upperBound - inset)
			let coverage = edgeShare(row: bottom, span: span, grid: grid)
			if coverage >= edgeCoverage {
				guard height >= minimumHeight,
					isFlatBar(rows: top..<bottom, span: span, grid: grid)
				else {
					return nil
				}
				let frame = CGRect(
					x: CGFloat(run.lowerBound) / scale,
					y: CGFloat(top) / scale,
					width: CGFloat(run.count) / scale,
					height: CGFloat(height) / scale
				)
				return DetectedLayer(frame: frame, cornerRadius: 0)
			}
			if coverage > interiorEdgeLimit {
				return nil
			}
		}
		return nil
	}

	private static func edgeShare(row: Int, span: ClosedRange<Int>, grid: PixelGrid) -> Double {
		let hits = span.filter { isEdge(column: $0, row: row, grid: grid) }.count
		return Double(hits) / Double(max(span.count, 1))
	}

	/// Fill, the row above and the row below each hold one colour; letters in a picture or a gradient don't.
	private static func isFlatBar(rows: Range<Int>, span: ClosedRange<Int>, grid: PixelGrid) -> Bool {
		let middleRow = (rows.lowerBound + rows.upperBound) / 2
		let probeRows = [rows.lowerBound - 1, middleRow, rows.upperBound]
		return probeRows.allSatisfy { row in
			guard row >= 0,
				row < grid.height
			else {
				return false
			}
			let reference = grid.color(column: span.lowerBound, row: row)
			return span.allSatisfy { grid.color(column: $0, row: row).difference(to: reference) <= flatThreshold }
		}
	}
}
