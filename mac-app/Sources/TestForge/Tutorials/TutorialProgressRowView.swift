import SwiftUI

struct TutorialProgressRowView: View {
	let feature: TutorialFeature
	let progress: TutorialProgress
	let replay: () -> Void

	var body: some View {
		LabeledContent {
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				Text(progressText)
					.foregroundStyle(.secondary)
					.monospacedDigit()
				Button("Replay", action: replay)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.tutorialReplayPrefix + feature.rawValue)
			}
		} label: {
			Text(feature.title)
		}
		.accessibilityElement(children: .contain)
	}

	private var progressText: String {
		switch progress {
			case .notSeen:
				return String(localized: "Not seen")
			case .inProgress(let step, let count):
				return String(localized: "In progress \(step)/\(count)")
			case .seen:
				return String(localized: "Seen")
		}
	}
}
