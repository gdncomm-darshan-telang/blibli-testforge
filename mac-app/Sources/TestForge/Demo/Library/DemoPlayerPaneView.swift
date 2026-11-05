import SwiftUI

/// AVKit's own player: play, pause, the scrubber and full screen come with it.
struct DemoPlayerPaneView: View {
	@ObservedObject var viewModel: DemoLibraryViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				Text(viewModel.selectedRecording?.macroName ?? "")
					.font(.headline)
					.lineLimit(1)
					.truncationMode(.middle)
					.help(viewModel.selectedRecording?.macroName ?? "")
					.accessibilityIdentifier(DemoLibraryConstants.Accessibility.playerTitle)
				Spacer()
				Picker("Language", selection: $viewModel.language) {
					ForEach(DemoLanguage.allCases) { language in
						Text(language.title).tag(language)
					}
				}
				.pickerStyle(.segmented)
				.fixedSize()
				.accessibilityIdentifier(DemoLibraryConstants.Accessibility.languagePicker)
				.tutorialAnchor(.demoLanguage)
				Button(action: viewModel.revealPlaying) {
					Label("Show in Finder", systemImage: "folder")
				}
				.accessibilityIdentifier(DemoLibraryConstants.Accessibility.reveal)
			}
			if let playing = viewModel.playingLanguage, playing != viewModel.language {
				Label("This demo has no \(viewModel.language.title) version; playing \(playing.title).", systemImage: "info.circle")
					.font(.callout)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier(DemoLibraryConstants.Accessibility.languageNote)
			}
			if let player = viewModel.player {
				DemoVideoPlayerView(player: player)
					.overlay {
						if !viewModel.isPlaying {
							DemoPlayOverlayView(play: viewModel.play)
						}
					}
					.tutorialAnchor(.demoPlayer)
				Label("Full screen: the ⤢ button at the bottom right of the video. Esc leaves it.", systemImage: "arrow.up.left.and.arrow.down.right")
					.font(.callout)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier(DemoLibraryConstants.Accessibility.fullScreenHint)
			}
		}
		.padding(TestForgeConstants.Spacing.large)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}
}
