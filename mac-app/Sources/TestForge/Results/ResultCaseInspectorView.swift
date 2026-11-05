import SwiftUI

struct ResultProofActions {
	let openFile: (URL) -> Void
	let showInFinder: (URL) -> Void
}

/// The selected case's verdict, review and proof: notes, screenshots, fake data that answered, Claude's words, steps.
struct ResultCaseInspectorView: View {
	let detail: ResultCaseDetailModel
	let reviewControls: ResultReviewControls
	let proofActions: ResultProofActions

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
				verdictSection
				ResultReviewBarView(reviewText: detail.reviewText, controls: reviewControls)
				ForEach(detail.notes) { note in
					noteRow(note: note)
				}
				showInFinderButton
				if !detail.screenshotURLs.isEmpty {
					ResultScreenshotStripView(urls: detail.screenshotURLs, openScreenshot: proofActions.openFile)
				}
				videosSection
				mocksSection
				summarySection
				stepsSection
			}
			.padding(TestForgeConstants.Spacing.large)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsInspector)
	}

	@ViewBuilder
	private var showInFinderButton: some View {
		if let proofURL = detail.proofLocationURL {
			Button {
				proofActions.showInFinder(proofURL)
			} label: {
				Label("Show in Finder", systemImage: "folder")
			}
			.help(proofURL.path)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsShowInFinderButton)
		}
	}

	/// Recorded runs (R4k): each video opens in the default player.
	@ViewBuilder
	private var videosSection: some View {
		if !detail.videoURLs.isEmpty {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text("Video proof (\(detail.videoURLs.count))")
					.font(.headline)
				ForEach(detail.videoURLs, id: \.self) { url in
					Button {
						proofActions.openFile(url)
					} label: {
						Label(url.lastPathComponent, systemImage: "film")
					}
					.buttonStyle(.link)
					.help(url.path)
				}
			}
			.accessibilityElement(children: .contain)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsVideos)
		}
	}

	private var verdictSection: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack {
				Text(detail.caseId)
					.font(.title3.monospaced().weight(.semibold))
				Spacer()
				VerdictBadgeView(text: detail.verdictText, tone: detail.verdictTone)
			}
			Text(detail.scenario)
				.textSelection(.enabled)
				.fixedSize(horizontal: false, vertical: true)
			Text(detail.historyText)
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}

	private func noteRow(note: ResultNoteModel) -> some View {
		Label {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(note.title)
					.font(.callout.weight(.semibold))
				Text(note.text)
					.font(.callout)
					.textSelection(.enabled)
					.fixedSize(horizontal: false, vertical: true)
			}
		} icon: {
			Image(systemName: note.symbolName)
		}
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsNote)
	}

	@ViewBuilder
	private var mocksSection: some View {
		if !detail.mocks.isEmpty {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text("Mocks that answered")
					.font(.headline)
				ForEach(detail.mocks, id: \.self) { mock in
					Text(mock)
						.font(.caption.monospaced())
						.textSelection(.enabled)
				}
			}
		}
	}

	@ViewBuilder
	private var summarySection: some View {
		if let summary = detail.summary {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text("What the run said")
					.font(.headline)
				Text(summary)
					.font(.callout)
					.textSelection(.enabled)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}

	@ViewBuilder
	private var stepsSection: some View {
		if !detail.steps.isEmpty {
			DisclosureGroup("Steps (\(detail.steps.count))") {
				ScrollView {
					Text(detail.steps.joined(separator: "\n"))
						.font(.caption.monospaced())
						.textSelection(.enabled)
						.frame(maxWidth: .infinity, alignment: .leading)
				}
				.frame(maxHeight: TestForgeConstants.Results.stepsMaxHeight)
			}
		}
	}
}
