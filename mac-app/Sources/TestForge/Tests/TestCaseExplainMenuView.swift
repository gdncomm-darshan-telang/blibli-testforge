import SwiftUI

struct TestCaseExplainActions {
	let canReplay: Bool

	/// Claude is writing the explanations right now; the menu waits for it.
	let isWriting: Bool

	/// False while a run starts or runs.
	let canWrite: Bool

	/// D-213: the request in flight; the menu's label shows it while an explained replay or a demo video starts.
	let busyAction: TestCaseAction?

	let replayExplained: () -> Void
	let recordDemo: () -> Void
	let writeExplanations: () -> Void
}

/// D-165: replays anyone can follow — subtitles and pointers over the Simulator, or a demo video with them burned in.
struct TestCaseExplainMenuView: View {
	let hasExplanations: Bool
	let actions: TestCaseExplainActions

	var body: some View {
		// A menu label can't show a spinner on macOS, so it sits beside the menu while the menu's work starts.
		HStack(spacing: TestForgeConstants.Spacing.small) {
			menu
			if busyTitle != nil {
				ProgressView()
					.controlSize(.small)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testsBusyLabel)
			}
		}
	}

	private var menu: some View {
		Menu {
			Button {
				actions.replayExplained()
			} label: {
				Label("Replay with explanations", systemImage: "captions.bubble")
			}
			.disabled(!actions.canReplay)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsExplainedReplayButton)
			Button {
				actions.recordDemo()
			} label: {
				Label("Record demo video", systemImage: "film")
			}
			.disabled(!actions.canReplay)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsRecordDemoButton)
			Divider()
			Button {
				actions.writeExplanations()
			} label: {
				Label(hasExplanations ? "Rewrite explanations with Claude…" : "Write explanations with Claude…", systemImage: "sparkles")
			}
			.disabled(actions.isWriting || !actions.canWrite)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsWriteExplanationsButton)
		} label: {
			Label(busyTitle ?? String(localized: "Explain"), systemImage: "captions.bubble")
		}
		.fixedSize()
		.disabled(!actions.canReplay && !actions.canWrite)
		.help(hasExplanations ? "Replays anyone can follow, in English or Bahasa Indonesia" : "No explanations yet — write them once with Claude")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsExplainMenu)
		.tutorialAnchor(.testsExplainMenu)
	}

	private var busyTitle: String? {
		switch actions.busyAction {
			case .replayWithExplanations:
				return String(localized: "Starting explained replay…")
			case .recordDemo:
				return String(localized: "Starting demo video…")
			default:
				return actions.isWriting ? String(localized: "Writing explanations…") : nil
		}
	}
}
