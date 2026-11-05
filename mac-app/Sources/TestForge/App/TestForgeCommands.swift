import SwiftUI

/// Xcode-style shortcuts: ⌘1–⌘8 sections, ⌘⇧Y console, ⌘R run, ⌘. stop; plus Simulator tools and server actions.
struct TestForgeCommands: Commands {
	@ObservedObject var viewModel: TestForgeViewModel
	@ObservedObject var preferences: TestForgePreferences
	@Environment(\.openWindow) private var openWindow

	var body: some Commands {
		CommandGroup(after: .sidebar) {
			Button("Show or Hide Console") {
				viewModel.toggleConsole()
			}
			.keyboardShortcut("y", modifiers: [.command, .shift])
			Toggle("Show Claude Usage", isOn: $preferences.isUsageBarShown)
				.keyboardShortcut("u", modifiers: [.command, .option])
			Divider()
			ForEach(TestForgeSection.allCases) { section in
				Button {
					viewModel.selectedSection = section
				} label: {
					Text(section.title)
				}
				.keyboardShortcut(section.shortcutKey, modifiers: .command)
			}
		}
		CommandMenu("Test") {
			Button("Run Selected Case") {
				viewModel.selectedSection = .tests
				viewModel.testsViewModel.runSelectedCase()
			}
			.keyboardShortcut("r", modifiers: .command)
			Button("Stop Run") {
				viewModel.testsViewModel.stopActiveRun()
			}
			.keyboardShortcut(".", modifiers: .command)
			Divider()
			Button("Load Test Document…") {
				viewModel.selectedSection = .tests
				viewModel.testsViewModel.isLoadSheetPresented = true
			}
		}
		CommandMenu("Simulator") {
			Toggle("Outline Steps", isOn: $preferences.isStepOverlayOn)
				.keyboardShortcut("o", modifiers: [.command, .option])
			Button("Measure") {
				openWindow(id: TestForgeConstants.Window.measureWindowId)
			}
			.keyboardShortcut("m", modifiers: [.command, .option])
		}
		CommandGroup(before: .help) {
			Button("Welcome to TestForge") {
				viewModel.onboardingViewModel.present()
			}
			.disabled(viewModel.isSetupNeeded)
		}
		CommandMenu("Server") {
			Button("Reconnect Live Updates") {
				viewModel.reconnect()
			}
			Button("Restart Server") {
				viewModel.restartServer()
			}
			.disabled(!viewModel.canRestartServer)
		}
	}

}
