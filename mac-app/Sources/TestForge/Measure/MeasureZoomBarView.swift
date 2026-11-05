import SwiftUI

/// Zoom out, a level slider, zoom in and fit, with the usual ⌘− ⌘= ⌘0 shortcuts.
struct MeasureZoomBarView: View {
	@ObservedObject var viewModel: MeasureViewModel

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.small) {
			Button {
				viewModel.zoomOut()
			} label: {
				Label("Zoom out", systemImage: "minus.magnifyingglass")
			}
			.keyboardShortcut("-", modifiers: .command)
			.disabled(!viewModel.canZoomOut)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.measureZoomOutButton)
			Slider(value: $viewModel.zoom, in: MeasureViewModel.zoomRange)
				.frame(width: TestForgeConstants.Measure.zoomSliderWidth)
				.help("Zoom level — or hold ⌥ and scroll, or pinch")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.measureZoomSlider)
			Button {
				viewModel.zoomIn()
			} label: {
				Label("Zoom in", systemImage: "plus.magnifyingglass")
			}
			.keyboardShortcut("=", modifiers: .command)
			.disabled(!viewModel.canZoomIn)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.measureZoomInButton)
			Button {
				viewModel.resetZoom()
			} label: {
				Label("Fit", systemImage: "arrow.down.right.and.arrow.up.left")
			}
			.keyboardShortcut("0", modifiers: .command)
			.help("Fit the whole screen (⌘0)")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.measureZoomFitButton)
			Text(viewModel.zoom, format: .percent.precision(.fractionLength(0)))
				.monospacedDigit()
				.foregroundStyle(.secondary)
				.frame(width: TestForgeConstants.Measure.zoomLabelWidth, alignment: .trailing)
		}
		.labelStyle(.iconOnly)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.measureZoomBar)
		.tutorialAnchor(.measureZoomBar)
	}
}
