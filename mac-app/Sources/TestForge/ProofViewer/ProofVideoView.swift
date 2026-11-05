import SwiftUI

struct ProofVideoView: View {
	@ObservedObject var viewModel: ProofVideoViewModel

	var body: some View {
		VStack(spacing: 0) {
			switch viewModel.state {
				case .empty:
					Color.clear
				case .loading:
					ProgressView()
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				case .failed(let message):
					ContentUnavailableView("Can't play this video", systemImage: "film.stack", description: Text(message))
				case .ready:
					ProofPlayerView(player: viewModel.player, magnification: viewModel.magnification)
					Divider()
					ProofPlaybackBarView(viewModel: viewModel)
						.frame(height: TestForgeConstants.ProofViewer.controlBarHeight)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerVideo)
	}
}
