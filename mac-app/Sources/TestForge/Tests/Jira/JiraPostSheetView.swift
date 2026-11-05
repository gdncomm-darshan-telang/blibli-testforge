import SwiftUI

/// Tests › Post to Jira (D-193): ticket from the document, the full comment to read and edit, then Post with a confirm.
struct JiraPostSheetView: View {
	@ObservedObject var viewModel: JiraPostViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			Text("Post result to Jira")
				.font(.title3.weight(.semibold))
			content
			buttons
		}
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(width: TestForgeConstants.GetReady.prerequisitesWidth)
		.confirmationDialog("Post this comment to \(viewModel.ticketKey)?", isPresented: $viewModel.isConfirmationShown) {
			Button("Post to \(viewModel.ticketKey)") {
				viewModel.confirmPost()
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.jiraPostConfirm)
		} message: {
			Text("Everyone watching the ticket sees it. A Jira comment can be edited or deleted later, but notifications go out at once.")
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.jiraPostSheet)
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.state {
			case .hidden, .loading:
				LoadingStateView(text: "Writing the comment…")
					.frame(maxWidth: .infinity)
			case .posting:
				LoadingStateView(text: "Posting to \(viewModel.ticketKey)…")
					.frame(maxWidth: .infinity)
			case .posted(let key):
				Label("Posted to \(key)", systemImage: "checkmark.circle.fill")
					.foregroundStyle(.green)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.jiraPostResult)
			case .failed(let message):
				Label(message, systemImage: "exclamationmark.triangle")
					.foregroundStyle(.red)
					.textSelection(.enabled)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.jiraPostResult)
			case .editing:
				editor
		}
	}

	private var editor: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			HStack {
				TextField("Ticket, e.g. SEA-123", text: $viewModel.ticketKey)
					.textFieldStyle(.roundedBorder)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.jiraPostTicket)
				if !viewModel.tickets.isEmpty {
					Menu("From the document") {
						ForEach(viewModel.tickets) { ticket in
							Button(ticket.key) {
								viewModel.ticketKey = ticket.key
							}
						}
					}
					.fixedSize()
					.accessibilityIdentifier(TestForgeConstants.Accessibility.jiraPostTicketMenu)
				}
			}
			if viewModel.tickets.isEmpty {
				Text("The document names no Jira ticket — type one.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			TextEditor(text: $viewModel.comment)
				.font(.callout.monospaced())
				.frame(minHeight: TestForgeConstants.GetReady.jiraCommentHeight)
				.overlay {
					RoundedRectangle(cornerRadius: TestForgeConstants.Tests.editNoticeCornerRadius)
						.strokeBorder(.separator)
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.jiraPostComment)
			if let historyText = viewModel.historyText {
				Text(historyText)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
	}

	private var buttons: some View {
		HStack {
			Spacer()
			Button(viewModel.state == .editing ? "Cancel" : "Close", role: .cancel) {
				viewModel.dismiss()
			}
			.keyboardShortcut(.cancelAction)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.jiraPostCancel)
			if viewModel.state == .editing {
				Button("Post…") {
					viewModel.requestPost()
				}
				.keyboardShortcut(.defaultAction)
				.disabled(!viewModel.canPost)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.jiraPostButton)
			}
		}
	}
}
