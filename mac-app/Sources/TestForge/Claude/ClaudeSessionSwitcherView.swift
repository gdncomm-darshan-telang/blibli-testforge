import SwiftUI

/// Which session the Claude section shows: the assistant, or a run's own (D-147). A session waiting on you is marked.
struct ClaudeSessionSwitcherView: View {
	let choices: [ClaudeSessionChoice]
	let select: (String) -> Void

	var body: some View {
		Menu {
			ForEach(choices) { choice in
				Button {
					select(choice.id)
				} label: {
					Label("\(choice.title) — \(choice.detail)", systemImage: symbolName(for: choice))
				}
			}
		} label: {
			Label(currentTitle, systemImage: hasWaitingSession ? "exclamationmark.bubble.fill" : "list.bullet")
		}
		.fixedSize()
		.help("Show another Claude session — runs and triage have their own")
		.accessibilityIdentifier(ClaudeConstants.Accessibility.sessionMenu)
		.tutorialAnchor(.claudeSessionMenu)
	}

	private var currentTitle: String {
		choices.first(where: \.isSelected)?.title ?? String(localized: "Sessions")
	}

	private var hasWaitingSession: Bool {
		choices.contains(where: \.needsYou)
	}

	private func symbolName(for choice: ClaudeSessionChoice) -> String {
		if choice.isSelected {
			return "checkmark"
		}
		return choice.needsYou ? "exclamationmark.bubble" : "bubble.left"
	}
}
