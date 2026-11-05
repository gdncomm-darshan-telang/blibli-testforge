import SwiftUI

/// Claude's own question (AskUserQuestion): pick options or type an answer; the picks are only form state until sent.
struct ClaudeQuestionCardView: View {
	let questions: [ClaudeQuestion]
	let status: ClaudeRequestStatus
	let send: (_ picks: [String: [String]]?) -> Void

	@State private var selections: [String: Set<String>] = [:]
	@State private var typedAnswers: [String: String] = [:]

	var body: some View {
		GroupBox {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
				ForEach(questions) { question in
					questionBlock(question)
				}
				footer
			}
			.padding(TestForgeConstants.Spacing.small)
		} label: {
			Label("Claude is asking", systemImage: "questionmark.bubble")
		}
	}

	@ViewBuilder
	private func questionBlock(_ question: ClaudeQuestion) -> some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text(question.header.isEmpty ? question.question : "\(question.header): \(question.question)")
				.bold()
			ForEach(question.options) { option in
				Toggle(isOn: selectionBinding(question: question, label: option.label)) {
					VStack(alignment: .leading) {
						Text(option.label)
						if !option.detail.isEmpty {
							Text(option.detail)
								.font(.callout)
								.foregroundStyle(.secondary)
						}
					}
				}
				.toggleStyle(.checkbox)
				.disabled(isLocked)
			}
			TextField("Other (type your own answer)", text: typedBinding(question: question))
				.textFieldStyle(.roundedBorder)
				.disabled(isLocked)
				.accessibilityIdentifier(ClaudeConstants.Accessibility.otherAnswerField)
		}
	}

	@ViewBuilder
	private var footer: some View {
		if let outcome = status.outcome {
			Text(outcome)
				.foregroundStyle(.secondary)
		} else {
			HStack {
				Button {
					send(picks)
				} label: {
					ActionProgressLabel(
						title: String(localized: "Send answer"),
						busyTitle: String(localized: "Sending…"),
						isBusy: status.pendingAction == .sendAnswer
					)
				}
				.keyboardShortcut(.defaultAction)
				.accessibilityIdentifier(ClaudeConstants.Accessibility.sendAnswerButton)
				Button {
					send(nil)
				} label: {
					ActionProgressLabel(title: String(localized: "Skip"), busyTitle: String(localized: "Skipping…"), isBusy: status.pendingAction == .skip)
				}
				.accessibilityIdentifier(ClaudeConstants.Accessibility.skipQuestionButton)
			}
			.disabled(status.pendingAction != nil)
			if let errorMessage = status.errorMessage {
				Label(errorMessage, systemImage: "exclamationmark.triangle")
					.font(.callout)
					.foregroundStyle(.red)
					.textSelection(.enabled)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.claudeQuestionFailure)
			}
		}
	}

	private var isLocked: Bool {
		status.outcome != nil || status.pendingAction != nil
	}

	private var picks: [String: [String]] {
		var result: [String: [String]] = [:]
		for question in questions {
			let chosen = question.options.map(\.label).filter { selections[question.question]?.contains($0) ?? false }
			let typed = (typedAnswers[question.question] ?? "").trimmingCharacters(in: .whitespaces)
			result[question.question] = typed.isEmpty ? chosen : chosen + [typed]
		}
		return result
	}

	/// A single-choice question keeps one pick, like a radio group.
	private func selectionBinding(question: ClaudeQuestion, label: String) -> Binding<Bool> {
		Binding {
			selections[question.question]?.contains(label) ?? false
		} set: { isOn in
			var chosen = question.isMultiSelect ? selections[question.question] ?? [] : []
			if isOn {
				chosen.insert(label)
			} else {
				chosen.remove(label)
			}
			selections[question.question] = chosen
		}
	}

	private func typedBinding(question: ClaudeQuestion) -> Binding<String> {
		Binding {
			typedAnswers[question.question] ?? ""
		} set: { text in
			typedAnswers[question.question] = text
		}
	}
}
