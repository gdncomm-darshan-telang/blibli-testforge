import SwiftUI

struct StepOverlayContentView: View {
	let content: StepOverlayContent

	var body: some View {
		Group {
			switch content {
				case .outline(let outline):
					StepOutlineView(outline: outline)
				case .explain(let overlay):
					ExplainOverlayView(overlay: overlay)
				case .busy(let overlay):
					StepBusyOverlayView(overlay: overlay)
			}
		}
		.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.content)
	}
}
