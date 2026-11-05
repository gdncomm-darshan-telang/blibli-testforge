import CoreGraphics

/// The visible ink of a text element (D-123): a label's frame is its line box, taller than the glyphs by the font's leading,
/// so spacing to the frame and spacing to what the eye sees differ. Background = the commonest colour on the frame's border.
enum TextInkDetector {
	static func inkBounds(of frame: CGRect, grid: PixelGrid) -> CGRect? {
		let scale = grid.pixelsPerPoint
		let minColumn = max(Int((frame.minX * scale).rounded(.down)), 0)
		let maxColumn = min(Int((frame.maxX * scale).rounded(.up)) - 1, grid.width - 1)
		let minRow = max(Int((frame.minY * scale).rounded(.down)), 0)
		let maxRow = min(Int((frame.maxY * scale).rounded(.up)) - 1, grid.height - 1)
		guard minColumn < maxColumn,
			minRow < maxRow
		else {
			return nil
		}
		let pixelBox = PixelBox(minColumn: minColumn, maxColumn: maxColumn, minRow: minRow, maxRow: maxRow)
		let background = backgroundColor(box: pixelBox, grid: grid)
		var inkColumns = (low: Int.max, high: Int.min)
		var inkRows = (low: Int.max, high: Int.min)
		for row in minRow...maxRow {
			for column in minColumn...maxColumn {
				let difference = grid.color(column: column, row: row).difference(to: background)
				guard difference > TestForgeConstants.Measure.inkThreshold else {
					continue
				}
				inkColumns = (min(inkColumns.low, column), max(inkColumns.high, column))
				inkRows = (min(inkRows.low, row), max(inkRows.high, row))
			}
		}
		guard inkColumns.low <= inkColumns.high,
			inkRows.low <= inkRows.high
		else {
			return nil
		}
		return CGRect(
			x: CGFloat(inkColumns.low) / scale,
			y: CGFloat(inkRows.low) / scale,
			width: CGFloat(inkColumns.high - inkColumns.low + 1) / scale,
			height: CGFloat(inkRows.high - inkRows.low + 1) / scale
		)
	}

	private static func backgroundColor(box: PixelBox, grid: PixelGrid) -> PixelColor {
		var counts: [PixelKey: Int] = [:]
		var samples: [PixelKey: PixelColor] = [:]
		let borderRows = [box.minRow, box.maxRow]
		let borderColumns = [box.minColumn, box.maxColumn]
		for row in borderRows {
			for column in box.minColumn...box.maxColumn {
				let color = grid.color(column: column, row: row)
				let key = PixelKey(color: color)
				counts[key, default: 0] += 1
				samples[key] = color
			}
		}
		for column in borderColumns {
			for row in box.minRow...box.maxRow {
				let color = grid.color(column: column, row: row)
				let key = PixelKey(color: color)
				counts[key, default: 0] += 1
				samples[key] = color
			}
		}
		let commonest = counts.max { $0.value < $1.value }?.key
		return commonest.flatMap { samples[$0] } ?? PixelColor(red: 255, green: 255, blue: 255)
	}
}

private struct PixelBox {
	let minColumn: Int
	let maxColumn: Int
	let minRow: Int
	let maxRow: Int
}

/// Groups near-identical colours so JPEG-like noise doesn't split the background vote.
private struct PixelKey: Hashable {
	let red: Int
	let green: Int
	let blue: Int

	init(color: PixelColor) {
		red = color.red / 8
		green = color.green / 8
		blue = color.blue / 8
	}
}
