import SwiftUI

struct ReportPreviewActions {
	let exportReport: () -> Void
	let copyReport: () -> Void
	let publish: () -> Void
}

struct ReportPreviewView: View {
	let preview: ReportPreviewModel
	let feedback: ReportPreviewFeedback
	let actions: ReportPreviewActions

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Text("Report preview")
				.font(.title3.weight(.semibold))
			GroupBox {
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
					Text(preview.title)
						.font(.headline)
					factsGrid
				}
				.padding(TestForgeConstants.Spacing.small)
				.frame(maxWidth: .infinity, alignment: .leading)
			}
			actionBar
			if let noticeText = feedback.noticeText {
				Label(noticeText, systemImage: "checkmark.circle")
					.font(.callout)
					.foregroundStyle(.secondary)
					.textSelection(.enabled)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.reportsPreview)
	}

	private var factsGrid: some View {
		Grid(alignment: .leading, horizontalSpacing: TestForgeConstants.Spacing.medium, verticalSpacing: TestForgeConstants.Spacing.small) {
			ForEach(preview.facts) { fact in
				GridRow {
					Text(fact.label)
						.foregroundStyle(.secondary)
					Text(fact.value)
						.textSelection(.enabled)
				}
				.font(.callout)
			}
		}
	}

	private var actionBar: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				Button {
					actions.exportReport()
				} label: {
					if feedback.isRunning(.exportReport) {
						ActionProgressLabel(title: String(localized: "Export Markdown…"), busyTitle: String(localized: "Exporting…"), isBusy: true)
					} else {
						Label("Export Markdown…", systemImage: "square.and.arrow.down")
					}
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.reportsExportButton)
				Button {
					actions.copyReport()
				} label: {
					if feedback.isRunning(.copyReport) {
						ActionProgressLabel(title: String(localized: "Copy report"), busyTitle: String(localized: "Copying…"), isBusy: true)
					} else {
						Label("Copy report", systemImage: "doc.on.doc")
					}
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.reportsCopyButton)
				Button {
					actions.publish()
				} label: {
					if feedback.isRunning(.publish) {
						ActionProgressLabel(title: String(localized: "Publish to my Confluence page…"), busyTitle: String(localized: "Queuing…"), isBusy: true)
					} else {
						Label("Publish to my Confluence page…", systemImage: "paperplane")
					}
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.reportsPublishButton)
			}
			.disabled(feedback.isBusy)
			Text("Publishes to your personal page only. The production test-case page is never written to.")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}
}
