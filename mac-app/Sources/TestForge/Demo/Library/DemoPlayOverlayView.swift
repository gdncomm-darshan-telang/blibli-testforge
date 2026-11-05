import SwiftUI

/// Big ▶ over a paused demo, so starting it doesn't depend on hovering for the player's own controls.
struct DemoPlayOverlayView: View {
	let play: () -> Void

	var body: some View {
		Button(action: play) {
			Image(systemName: "play.circle.fill")
				.font(.system(size: DemoLibraryConstants.playOverlaySize))
				.symbolRenderingMode(.palette)
				.foregroundStyle(.white, Color.black.opacity(DemoLibraryConstants.playOverlayShade))
				.shadow(radius: TestForgeConstants.Spacing.small)
		}
		.buttonStyle(.plain)
		.keyboardShortcut(.space, modifiers: [])
		.help("Play (Space)")
		.accessibilityLabel(Text("Play demo"))
		.accessibilityIdentifier(DemoLibraryConstants.Accessibility.playOverlay)
	}
}
