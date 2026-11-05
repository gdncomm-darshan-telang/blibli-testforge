import SwiftUI

struct ProofZoomActions {
	let zoomIn: () -> Void
	let zoomOut: () -> Void
	let fit: () -> Void
	let actualSize: () -> Void
}

struct ProofZoomBarView: View {
	let zoomPercent: Int
	let actions: ProofZoomActions

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Spacer()
			Button(action: actions.zoomOut) {
				Image(systemName: "minus.magnifyingglass")
			}
			.keyboardShortcut("-", modifiers: .command)
			.help("Zoom out (⌘−)")
			.accessibilityLabel("Zoom out")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerZoomOut)
			Text("\(zoomPercent) %")
				.font(.callout.monospacedDigit())
				.frame(minWidth: TestForgeConstants.ProofViewer.zoomTextWidth)
			Button(action: actions.zoomIn) {
				Image(systemName: "plus.magnifyingglass")
			}
			.keyboardShortcut("+", modifiers: .command)
			.help("Zoom in (⌘+)")
			.accessibilityLabel("Zoom in")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerZoomIn)
			Divider()
				.frame(height: TestForgeConstants.ProofViewer.barDividerHeight)
			Button(action: actions.fit) {
				Label("Fit", systemImage: "arrow.down.right.and.arrow.up.left")
			}
			.keyboardShortcut("0", modifiers: .command)
			.help("Fit to window (⌘0)")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerFit)
			Button(action: actions.actualSize) {
				Label("Actual size", systemImage: "1.magnifyingglass")
			}
			.keyboardShortcut("1", modifiers: .command)
			.help("Actual size (⌘1)")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerActualSize)
			Spacer()
		}
		.buttonStyle(.borderless)
		.padding(.horizontal, TestForgeConstants.Spacing.large)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerZoomBar)
	}
}
