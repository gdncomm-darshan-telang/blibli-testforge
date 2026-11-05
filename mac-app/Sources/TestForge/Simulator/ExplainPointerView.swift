import SwiftUI

/// Yellow box with a tap dot for an action, blue while a check runs, green or red with a badge once it is decided.
struct ExplainPointerView: View {
	let pointer: ExplainPointer
	let width: CGFloat

	private var color: Color {
		pointer.color
	}

	private var rect: CGRect {
		pointer.outlineRect(width: width)
	}

	private var corner: CGFloat {
		width * ExplainOverlayConstants.Pointer.cornerShare
	}

	private var dotSize: CGFloat {
		width * ExplainOverlayConstants.Pointer.tapDotShare * 2
	}

	var body: some View {
		ZStack(alignment: .topLeading) {
			outline
			if pointer.style == .action {
				tapDot
			}
			if let badge = pointer.badge,
				let frame = pointer.badgeFrame(width: width) {
				badgeView(badge, frame: frame)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.pointer)
	}

	private var outline: some View {
		RoundedRectangle(cornerRadius: corner)
			.fill(color.opacity(ExplainOverlayConstants.Pointer.fillOpacity))
			.overlay(RoundedRectangle(cornerRadius: corner).stroke(color, lineWidth: width * ExplainOverlayConstants.Pointer.lineShare))
			.frame(width: rect.width, height: rect.height)
			.offset(x: rect.minX, y: rect.minY)
			.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.pointerOutline)
	}

	private var tapDot: some View {
		Circle()
			.fill(color.opacity(ExplainOverlayConstants.Pointer.dotOpacity))
			.frame(width: dotSize, height: dotSize)
			.offset(x: rect.midX - dotSize / 2, y: rect.midY - dotSize / 2)
			.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.pointerTapDot)
	}

	private func badgeView(_ badge: String, frame: CGRect) -> some View {
		let fontSize = width * ExplainOverlayConstants.Pointer.badgeShare
		return Text(badge)
			.font(.system(size: fontSize, weight: .bold))
			.foregroundStyle(.white)
			.lineLimit(1)
			.minimumScaleFactor(0.8)
			.frame(width: frame.width, height: frame.height)
			.background(color, in: RoundedRectangle(cornerRadius: fontSize * 0.5))
			.offset(x: frame.minX, y: frame.minY)
			.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.pointerBadge)
	}
}
