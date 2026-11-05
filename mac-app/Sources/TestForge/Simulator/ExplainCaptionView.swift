import SwiftUI

struct ExplainCaptionContent {
	let text: String
	let placement: ExplainCaptionPlacement

	/// The pointer's color, so the box's border and tail match the element it points at; nil when nothing is pointed at.
	let accent: Color?
}

/// The step's words in a rounded box at the spot the placer picked, its tail aimed at the element.
struct ExplainCaptionView: View {
	let content: ExplainCaptionContent
	let width: CGFloat

	private typealias Metrics = ExplainOverlayConstants.Caption

	private var fontSize: CGFloat {
		width * Metrics.fontShare
	}

	private var frame: CGRect {
		content.placement.frame
	}

	private var bubble: ExplainCalloutShape {
		let tail = content.placement.tail.map { tail in
			let origin = frame.origin
			let base = CGPoint(x: tail.base.x - origin.x, y: tail.base.y - origin.y)
			let tip = CGPoint(x: tail.tip.x - origin.x, y: tail.tip.y - origin.y)
			return ExplainCaptionTail(base: base, tip: tip, edge: tail.edge)
		}
		return ExplainCalloutShape(tail: tail, corner: fontSize * Metrics.cornerFontShare, tailHalfWidth: width * Metrics.tailHalfWidthShare)
	}

	var body: some View {
		Text(content.text)
			.font(.system(size: fontSize, weight: .semibold))
			.foregroundStyle(.white)
			.multilineTextAlignment(.center)
			.minimumScaleFactor(0.85)
			.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.captionText)
			.padding(.horizontal, fontSize * Metrics.horizontalPadFontShare)
			.padding(.vertical, fontSize * Metrics.verticalPadFontShare)
			.frame(width: frame.width, height: frame.height)
			.background {
				bubble
					.fill(Metrics.background)
					.overlay(bubble.stroke(content.accent ?? Metrics.plainBorder, lineWidth: width * Metrics.borderShare))
					.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.captionBubble)
			}
			.offset(x: frame.minX, y: frame.minY)
			.accessibilityElement(children: .contain)
			.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.caption)
	}
}
