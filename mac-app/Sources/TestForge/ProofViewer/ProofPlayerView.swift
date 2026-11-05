import AVKit
import SwiftUI

/// AVKit's player view without its own controls (the playback bar owns them); it still zooms with a trackpad pinch.
struct ProofPlayerView: NSViewRepresentable {
	let player: AVPlayer
	let magnification: CGFloat

	func makeNSView(context: Context) -> AVPlayerView {
		let playerView = AVPlayerView()
		playerView.player = player
		playerView.controlsStyle = .none
		playerView.videoGravity = .resizeAspect
		playerView.allowsMagnification = true
		playerView.setAccessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerPlayer)
		return playerView
	}

	func updateNSView(_ playerView: AVPlayerView, context: Context) {
		if playerView.player !== player {
			playerView.player = player
		}
		if abs(playerView.magnification - magnification) > TestForgeConstants.ProofViewer.magnificationTolerance {
			playerView.magnification = magnification
		}
	}
}
