import SwiftUI

struct MenuBarActions {
	let openTestForge: () -> Void
	let quit: () -> Void
}

/// The menu-bar menu (board C11 "Run progress and Stop while the window is hidden").
struct MenuBarStatusView: View {
	@ObservedObject var viewModel: RunActivityViewModel
	let actions: MenuBarActions
	@Environment(\.openWindow) private var openWindow

	var body: some View {
		Group {
			statusSection
			if let stopError = viewModel.stopError {
				Text("Failed: \(stopError)")
					.accessibilityIdentifier(TestForgeConstants.Accessibility.menuBarControlFailure)
			}
			Divider()
			Button("Open TestForge") {
				openWindow(id: TestForgeConstants.Window.mainWindowId)
				actions.openTestForge()
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.menuBarOpen)
			Button("Quit TestForge") {
				actions.quit()
			}
			.keyboardShortcut("q")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.menuBarQuit)
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.menuBar)
	}

	@ViewBuilder
	private var statusSection: some View {
		switch viewModel.state {
			case .idle(let lastResult):
				Text("No run in progress")
					.accessibilityIdentifier(TestForgeConstants.Accessibility.menuBarStatus)
				if let lastResult {
					Text(lastResult)
				}
			case .running(let progress):
				Text(progress.title)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.menuBarStatus)
				Text(progress.detail)
				if let stepText = progress.stepText {
					Text(stepText)
				}
				if let pauseReason = progress.pauseReason {
					Text(pauseReason)
					Button(viewModel.pendingControl == .resume ? "Continuing…" : "Continue") {
						viewModel.resume()
					}
					.disabled(viewModel.pendingControl != nil)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.menuBarContinue)
				}
				Button(viewModel.pendingControl == .stop ? "Stopping…" : "Stop") {
					viewModel.stop()
				}
				.disabled(viewModel.pendingControl != nil)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.menuBarStop)
		}
	}
}
