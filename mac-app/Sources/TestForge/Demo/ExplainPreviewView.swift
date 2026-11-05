import SwiftUI

/// The recording's frame with the live overlay on top, as a viewer would see the Simulator.
struct ExplainPreviewView: View {
	let overlay: ExplainOverlay
	let frame: CGImage?

	var body: some View {
		ZStack(alignment: .topLeading) {
			if let frame {
				Image(decorative: frame, scale: 1)
					.resizable()
					.frame(width: overlay.panelFrame.width, height: overlay.panelFrame.height)
					.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.previewFrame)
			}
			ExplainOverlayView(overlay: overlay)
		}
		.frame(width: overlay.panelFrame.width, height: overlay.panelFrame.height)
		.background(Color.black)
		.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.preview)
	}
}
