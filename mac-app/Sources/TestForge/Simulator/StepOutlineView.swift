import SwiftUI

struct StepOutline: Equatable {
	let number: Int
	let text: String

	/// Where the panel sits: the Simulator's device screen, in AppKit coordinates.
	let panelFrame: CGRect

	/// The element's rect inside the panel, top-left origin.
	let outlineRect: CGRect
}

/// Drawn in a click-through panel over the Simulator screen; it only draws, never captures.
struct StepOutlineView: View {
	let outline: StepOutline

	var body: some View {
		ZStack(alignment: .topLeading) {
			RoundedRectangle(cornerRadius: TestForgeConstants.Overlay.outlineCornerRadius)
				.stroke(Color.accentColor, lineWidth: TestForgeConstants.Overlay.outlineLineWidth)
				.frame(width: outline.outlineRect.width, height: outline.outlineRect.height)
				.offset(x: outline.outlineRect.minX, y: outline.outlineRect.minY)
			StepOutlineBadgeView(number: outline.number, text: outline.text)
				.offset(x: outline.outlineRect.minX, y: badgeOffsetY)
		}
		.frame(width: outline.panelFrame.width, height: outline.panelFrame.height, alignment: .topLeading)
		.allowsHitTesting(false)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.stepOutline)
	}

	/// Above the element when there is room, otherwise below it.
	private var badgeOffsetY: CGFloat {
		let badgeHeight = TestForgeConstants.Overlay.badgeHeight
		let above = outline.outlineRect.minY - badgeHeight - TestForgeConstants.Spacing.small
		return above >= 0 ? above : outline.outlineRect.maxY + TestForgeConstants.Spacing.small
	}
}
