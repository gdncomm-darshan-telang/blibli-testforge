import SwiftUI

/// The busy banner alone over the Simulator, for a replay that isn't explained.
struct StepBusyOverlayView: View {
	let overlay: StepBusyOverlay

	var body: some View {
		VStack {
			StepBusyBannerView(message: overlay.message, width: overlay.panelFrame.width)
				.padding(.top, overlay.panelFrame.width * ExplainOverlayConstants.Busy.topShare)
			Spacer()
		}
		.frame(width: overlay.panelFrame.width, height: overlay.panelFrame.height)
		.allowsHitTesting(false)
		.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.busyOverlay)
	}
}
