import SwiftUI

/// Play / pause (space), stop, frame steps (, and .), seeking, speed and zoom for the proof video.
struct ProofPlaybackBarView: View {
	@ObservedObject var viewModel: ProofVideoViewModel

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			transportButtons
			Text(viewModel.currentTimeText)
				.font(.callout.monospacedDigit())
			Slider(value: seekPosition, in: 0...max(viewModel.durationSeconds, TestForgeConstants.ProofViewer.minimumSliderRange))
				.accessibilityLabel("Position")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerScrubber)
			Text(viewModel.durationText)
				.font(.callout.monospacedDigit())
				.foregroundStyle(.secondary)
			speedMenu
			zoomButtons
		}
		.buttonStyle(.borderless)
		.padding(.horizontal, TestForgeConstants.Spacing.large)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerPlaybackBar)
	}

	@ViewBuilder
	private var transportButtons: some View {
		Button {
			viewModel.step(byFrames: -1)
		} label: {
			Image(systemName: "backward.frame.fill")
		}
		.keyboardShortcut(",", modifiers: [])
		.help("Back one frame (,)")
		.accessibilityLabel("Back one frame")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerFrameBack)
		Button(action: viewModel.togglePlay) {
			Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
				.frame(width: TestForgeConstants.ProofViewer.playButtonWidth)
		}
		.keyboardShortcut(.space, modifiers: [])
		.help(viewModel.isPlaying ? "Pause (space)" : "Play (space)")
		.accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerPlay)
		Button(action: viewModel.stop) {
			Image(systemName: "stop.fill")
		}
		.help("Stop and go back to the start")
		.accessibilityLabel("Stop")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerStop)
		Button {
			viewModel.step(byFrames: 1)
		} label: {
			Image(systemName: "forward.frame.fill")
		}
		.keyboardShortcut(".", modifiers: [])
		.help("Forward one frame (.)")
		.accessibilityLabel("Forward one frame")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerFrameForward)
	}

	private var speedMenu: some View {
		Menu {
			ForEach(TestForgeConstants.ProofViewer.playbackRates, id: \.self) { rate in
				Button {
					viewModel.setRate(to: rate)
				} label: {
					if rate == viewModel.rate {
						Label(ProofVideoViewModel.rateText(rate: rate), systemImage: "checkmark")
					} else {
						Text(ProofVideoViewModel.rateText(rate: rate))
					}
				}
			}
		} label: {
			Label(ProofVideoViewModel.rateText(rate: viewModel.rate), systemImage: "gauge.with.dots.needle.67percent")
		}
		.menuStyle(.borderlessButton)
		.fixedSize()
		.help("Playback speed")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerSpeed)
	}

	@ViewBuilder
	private var zoomButtons: some View {
		Button(action: viewModel.zoomOut) {
			Image(systemName: "minus.magnifyingglass")
		}
		.keyboardShortcut("-", modifiers: .command)
		.help("Zoom out (⌘−)")
		.accessibilityLabel("Zoom out")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerZoomOut)
		Button(action: viewModel.zoomIn) {
			Image(systemName: "plus.magnifyingglass")
		}
		.keyboardShortcut("+", modifiers: .command)
		.help("Zoom in (⌘+); pinch also zooms")
		.accessibilityLabel("Zoom in")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerZoomIn)
		Button(action: viewModel.resetZoom) {
			Image(systemName: "arrow.down.right.and.arrow.up.left")
		}
		.keyboardShortcut("0", modifiers: .command)
		.help("Fit to window (⌘0)")
		.accessibilityLabel("Fit")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerFit)
	}

	private var seekPosition: Binding<Double> {
		let viewModel = viewModel
		return Binding {
			viewModel.currentSeconds
		} set: { seconds in
			viewModel.seek(toSeconds: seconds)
		}
	}
}
