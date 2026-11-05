import SwiftUI

struct ResultRunActions {
	let rerunFailed: () -> Void
	let exportReport: () -> Void
	let copyReport: () -> Void
	let exportBundle: () -> Void
	let showProofInFinder: (URL) -> Void
}

struct ResultRunHeaderView: View {
	let header: ResultRunHeaderModel
	let controls: ResultRunControls

	private var actions: ResultRunActions {
		controls.actions
	}

	private var feedback: ResultActionFeedback {
		controls.feedback
	}

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			titleRow
			factsGrid
			if let warning = header.warning {
				Label(warning, systemImage: "exclamationmark.triangle.fill")
					.font(.callout)
					.foregroundStyle(.orange)
			}
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				ForEach(header.tiles) { tile in
					ResultTileView(tile: tile)
				}
			}
			actionBar
		}
		.padding(TestForgeConstants.Spacing.large)
		.frame(maxWidth: .infinity, alignment: .leading)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsRunHeader)
		.tutorialAnchor(.resultsRunHeader)
	}

	private var titleRow: some View {
		HStack(alignment: .firstTextBaseline) {
			Text(header.title)
				.font(.title2.weight(.semibold))
			Spacer()
			Label(header.reviewText, systemImage: header.isValidated ? "checkmark.seal.fill" : "hourglass")
				.font(.callout)
				.foregroundStyle(header.isValidated ? .green : .secondary)
		}
	}

	private var factsGrid: some View {
		Grid(alignment: .leading, horizontalSpacing: TestForgeConstants.Spacing.medium, verticalSpacing: TestForgeConstants.Spacing.small) {
			ForEach(header.facts) { fact in
				GridRow {
					Text(fact.label)
						.foregroundStyle(.secondary)
					Text(fact.value)
						.textSelection(.enabled)
						.lineLimit(1)
						.truncationMode(.middle)
				}
				.font(.callout)
			}
		}
	}

	private var actionBar: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				rerunButton
				Button {
					actions.exportReport()
				} label: {
					progressLabel(action: .exportReport)
				}
				.help("Save the Markdown report")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsExportButton)
				Button {
					actions.copyReport()
				} label: {
					progressLabel(action: .copyReport)
				}
				.help("Copy the Markdown report")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsCopyButton)
				Button {
					actions.exportBundle()
				} label: {
					progressLabel(action: .exportBundle)
				}
				.help("Save this run as one file — cases, macros, mocks and verdicts — so the next person replays it without Claude")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsExportBundleButton)
				.tutorialAnchor(.resultsExportBundleButton)
			}
			.disabled(feedback.isBusy)
			if let confirmation = feedback.runConfirmation {
				Label(confirmation, systemImage: "checkmark.circle")
					.font(.callout)
					.foregroundStyle(.secondary)
					.textSelection(.enabled)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsRunActionConfirmation)
			}
		}
	}

	private var rerunButton: some View {
		Button {
			actions.rerunFailed()
		} label: {
			progressLabel(action: .rerunFailed)
		}
		.disabled(!header.canRerunFailed)
		.help("Runs this run's failures once more; a case that then passes is marked flaky")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsRerunFailedButton)
		.tutorialAnchor(.resultsRerunFailedButton)
	}

	@ViewBuilder
	private func progressLabel(action: ResultAction) -> some View {
		let text = ResultActionLabelText(action: action)
		if feedback.isRunning(action) {
			ActionProgressLabel(title: text.title, busyTitle: text.busyTitle, isBusy: true)
		} else {
			Label(text.title, systemImage: text.systemImage)
		}
	}
}
