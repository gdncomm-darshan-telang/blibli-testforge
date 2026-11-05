import SwiftUI

struct SessionReportView: View {
	@ObservedObject var viewModel: SessionReportViewModel

	var body: some View {
		VStack(spacing: 0) {
			actionBar
			Divider()
			content
		}
		.onAppear {
			viewModel.load()
		}
		.confirmationDialog("Publish this session report to Confluence?", isPresented: $viewModel.isPublishConfirmationPresented) {
			Button("Publish with Claude") {
				viewModel.confirmPublish()
			}
			.accessibilityIdentifier(ReportsConstants.Accessibility.sessionPublishConfirm)
			Button("Cancel", role: .cancel) {
				viewModel.isPublishConfirmationPresented = false
			}
		} message: {
			Text(Self.publishMessage)
		}
		.alert("That didn't work", isPresented: isActionMessagePresented) {
			Button("OK", action: viewModel.dismissMessage)
		} message: {
			Text(viewModel.actionMessage ?? "")
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(ReportsConstants.Accessibility.sessionReport)
	}

	private var actionBar: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				Button(action: viewModel.load) {
					if viewModel.isRunning(.refresh) {
						ActionProgressLabel(title: String(localized: "Refresh"), busyTitle: String(localized: "Refreshing…"), isBusy: true)
					} else {
						Label("Refresh", systemImage: "arrow.clockwise")
					}
				}
				.disabled(viewModel.runningAction != nil)
				.help("Rebuild the report from the latest runs")
				.accessibilityIdentifier(ReportsConstants.Accessibility.sessionRefresh)
				Spacer()
				Button(action: viewModel.copyMarkdown) {
					Label("Copy", systemImage: "doc.on.doc")
				}
				.disabled(!viewModel.canShare)
				.accessibilityIdentifier(ReportsConstants.Accessibility.sessionCopy)
				Menu {
					Button("Markdown (.md)…", action: viewModel.exportMarkdown)
						.accessibilityIdentifier(ReportsConstants.Accessibility.sessionExportMarkdown)
					Button("For Confluence (.html)…", action: viewModel.exportConfluence)
						.accessibilityIdentifier(ReportsConstants.Accessibility.sessionExportConfluence)
				} label: {
					Label("Export", systemImage: "square.and.arrow.up")
				}
				.fixedSize()
				.disabled(!viewModel.canShare)
				.accessibilityIdentifier(ReportsConstants.Accessibility.sessionExportMenu)
				if viewModel.isExporting {
					exportProgress
				}
				Button {
					viewModel.isPublishConfirmationPresented = true
				} label: {
					if viewModel.isRunning(.publish) {
						ActionProgressLabel(title: String(localized: "Publish to my Confluence page…"), busyTitle: String(localized: "Queuing…"), isBusy: true)
					} else {
						Label("Publish to my Confluence page…", systemImage: "paperplane")
					}
				}
				.buttonStyle(.borderedProminent)
				.disabled(!viewModel.canShare)
				.accessibilityIdentifier(ReportsConstants.Accessibility.sessionPublish)
				.tutorialAnchor(.sessionReportPublish)
			}
			if let notice = viewModel.noticeText {
				Label(notice, systemImage: "checkmark.circle")
					.font(.callout)
					.foregroundStyle(.secondary)
					.textSelection(.enabled)
					.accessibilityIdentifier(ReportsConstants.Accessibility.sessionNotice)
			}
		}
		.padding(TestForgeConstants.Spacing.large)
	}

	/// A menu's label can't hold a spinner, so it sits beside the Export menu until the save panel opens and closes.
	private var exportProgress: some View {
		HStack(spacing: TestForgeConstants.Spacing.small) {
			ProgressView()
				.controlSize(.small)
			Text("Exporting…")
				.font(.callout)
		}
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.sessionExportProgress)
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.state {
			case .loading:
				LoadingStateView(text: "Building the report…")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .loaded(let blocks):
				MarkdownView(blocks: blocks)
					.tutorialAnchor(.sessionReportViewer)
			case .failed(let message):
				ContentUnavailableView {
					Label("No session report", systemImage: "doc.text.magnifyingglass")
				} description: {
					Text(message)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
	}

	private var isActionMessagePresented: Binding<Bool> {
		Binding {
			viewModel.actionMessage != nil
		} set: { isPresented in
			if !isPresented {
				viewModel.dismissMessage()
			}
		}
	}

	private static let publishMessage: LocalizedStringKey = """
		Claude creates one new page under your personal Confluence page, with the report's tables and verdicts. \
		Screenshots stay in the session export. The production test-case page is never written to. This uses your Claude plan.
		"""
}
