import AVKit
import SwiftUI

/// AVKit's player with its own controls plus the full-screen button, which SwiftUI's `VideoPlayer` leaves out on macOS.
struct DemoVideoPlayerView: NSViewRepresentable {
	let player: AVPlayer

	func makeNSView(context: Context) -> AVPlayerView {
		let playerView = AVPlayerView()
		playerView.player = player
		playerView.controlsStyle = .floating
		playerView.showsFullScreenToggleButton = true
		playerView.videoGravity = .resizeAspect
		playerView.setAccessibilityIdentifier(DemoLibraryConstants.Accessibility.player)
		return playerView
	}

	func updateNSView(_ playerView: AVPlayerView, context: Context) {
		if playerView.player !== player {
			playerView.player = player
		}
	}
}
