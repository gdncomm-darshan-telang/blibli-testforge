import SwiftUI

struct ResultReviewActions {
	let accept: () -> Void
	let override: () -> Void
	let markForRerun: () -> Void
}

/// A run counts as validated only when every case is accepted or overridden.
struct ResultReviewBarView: View {
	let reviewText: String
	let controls: ResultReviewControls

	private var feedback: ResultActionFeedback {
		controls.feedback
	}

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack {
				Text("Review")
					.font(.headline)
				Spacer()
				Text(reviewText)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(2)
			}
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				Button {
					controls.actions.accept()
				} label: {
					ActionProgressLabel(title: String(localized: "Accept"), busyTitle: String(localized: "Saving…"), isBusy: feedback.isRunning(.accept))
				}
				.buttonStyle(.borderedProminent)
				.help("The verdict is right")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsAcceptButton)
				Button("Override…") {
					controls.actions.override()
				}
				.help("Change the verdict to PASS or FAIL and say why")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsOverrideButton)
				Button {
					controls.actions.markForRerun()
				} label: {
					ActionProgressLabel(title: String(localized: "Needs re-run"), busyTitle: String(localized: "Saving…"), isBusy: feedback.isRunning(.needsRerun))
				}
				.help("Include this case in Re-run failed")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsNeedsRerunButton)
			}
			.disabled(feedback.isBusy)
			if let confirmation = feedback.reviewConfirmation {
				Label(confirmation, systemImage: "checkmark.circle")
					.font(.caption)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsReviewConfirmation)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsReviewBar)
	}
}
