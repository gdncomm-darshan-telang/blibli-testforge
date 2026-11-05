import SwiftUI

/// One spacing line from the selected element's edge, labelled with the distance in points.
struct MeasureGapLineView: View {
	let gap: MeasureGap
	let scale: CGFloat
	var tint: Color = .orange

	var body: some View {
		ZStack(alignment: .topLeading) {
			Path { path in
				path.move(to: scaledStart)
				path.addLine(to: scaledEnd)
			}
			.stroke(tint, lineWidth: TestForgeConstants.Measure.gapLineWidth)
			Text(MeasureFormatting.points(gap.distance))
				.font(.caption2.monospacedDigit().bold())
				.foregroundStyle(.white)
				.padding(.horizontal, TestForgeConstants.Spacing.small)
				.background(tint, in: Capsule())
				.fixedSize()
				.position(labelPosition)
		}
		.allowsHitTesting(false)
	}

	private var scaledStart: CGPoint {
		CGPoint(x: gap.start.x * scale, y: gap.start.y * scale)
	}

	private var scaledEnd: CGPoint {
		CGPoint(x: gap.end.x * scale, y: gap.end.y * scale)
	}

	private var labelPosition: CGPoint {
		CGPoint(x: (scaledStart.x + scaledEnd.x) / 2, y: (scaledStart.y + scaledEnd.y) / 2)
	}
}

enum MeasureFormatting {
	/// Snapped to the half point first: scaled-back Simulator frames carry float noise like 16.000001.
	static func points(_ value: CGFloat) -> String {
		let snapped = MeasureCalculator.rounded(value)
		let isWhole = snapped.rounded() == snapped
		return isWhole ? String(format: "%.0f", snapped) : String(format: "%.1f", snapped)
	}

	static func sizeText(_ size: CGSize) -> String {
		"\(points(size.width)) × \(points(size.height))"
	}

	static func pointText(_ point: CGPoint) -> String {
		"x \(points(point.x)) · y \(points(point.y))"
	}

	static func insetsText(_ insets: [MeasureEdge: CGFloat]) -> String {
		let parts = MeasureEdge.allCases.compactMap { edge in
			insets[edge].map { "\(edge.plainTitle) \(points($0))" }
		}
		return parts.joined(separator: " · ")
	}

	static func frameText(_ frame: CGRect) -> String {
		"x \(points(frame.minX)) · y \(points(frame.minY)) · \(points(frame.width)) × \(points(frame.height))"
	}
}
