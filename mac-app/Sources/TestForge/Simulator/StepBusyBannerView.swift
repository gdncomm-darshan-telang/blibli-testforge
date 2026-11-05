import SwiftUI

/// A spinner with what the phone is busy with, sized from the Simulator screen's width like the rest of the overlay.
struct StepBusyBannerView: View {
	let message: String
	let width: CGFloat

	private var fontSize: CGFloat {
		width * ExplainOverlayConstants.Busy.fontShare
	}

	var body: some View {
		HStack(spacing: fontSize * 0.6) {
			ProgressView()
				.controlSize(.small)
				.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.busySpinner)
			Text(message)
				.font(.system(size: fontSize, weight: .semibold))
				.foregroundStyle(.white)
				.lineLimit(2)
				.multilineTextAlignment(.leading)
				.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.busyText)
		}
		.padding(.horizontal, fontSize * 0.8)
		.padding(.vertical, fontSize * 0.55)
		.background(ExplainOverlayConstants.Busy.background, in: Capsule())
		.overlay(Capsule().stroke(ExplainOverlayConstants.Busy.border, lineWidth: 1))
		.environment(\.colorScheme, .dark)
		.frame(maxWidth: width * ExplainOverlayConstants.Busy.maxWidthShare)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.busyBanner)
	}
}
