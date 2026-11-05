import SwiftUI

struct EditTestCaseSheetActions {
	let save: (TestCaseDraft) -> Void
	let cancel: () -> Void
}

/// Stays open while Save runs (D-213) and closes once the server saved; a failure shows above the buttons.
struct EditTestCaseSheetView: View {
	let actions: EditTestCaseSheetActions
	let status: TestCaseSheetStatus
	@State private var draft: TestCaseDraft

	init(draft: TestCaseDraft, actions: EditTestCaseSheetActions, status: TestCaseSheetStatus) {
		self.actions = actions
		self.status = status
		_draft = State(initialValue: draft)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			Text("Edit case \(draft.id)")
				.font(.headline)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.editSheetTitle)
			Text(Self.noteText)
				.font(.callout)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.editSheetNote)
			ScrollView {
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
					EditTestCaseFieldView(title: "Scenario", fieldId: "scenario", text: $draft.scenario)
					EditTestCaseFieldView(title: "Precondition", fieldId: "precondition", text: $draft.precondition)
					EditTestCaseFieldView(title: "Steps", fieldId: "steps", text: $draft.steps)
					EditTestCaseFieldView(title: "Expected result", fieldId: "expected", text: $draft.expected)
					EditTestCaseFieldView(title: "API", fieldId: "api", text: $draft.api)
				}
			}
			if let failureMessage = status.failureMessage {
				Label(failureMessage, systemImage: "exclamationmark.triangle")
					.foregroundStyle(.red)
					.fixedSize(horizontal: false, vertical: true)
					.textSelection(.enabled)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.editSheetFailure)
			}
			buttonRow
		}
		.disabled(status.isSaving)
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(width: TestForgeConstants.Tests.editSheetWidth)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.editSheet)
	}

	private static let noteText: LocalizedStringKey = """
		Your text is used for runs, recordings and explanations on this Mac, and travels in run bundles. \
		The test document is never changed, so tell its owner if it is wrong there too.
		"""

	private var buttonRow: some View {
		HStack {
			Spacer()
			Button("Cancel", role: .cancel) {
				actions.cancel()
			}
			.keyboardShortcut(.cancelAction)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.editSheetCancel)
			Button {
				actions.save(draft)
			} label: {
				ActionProgressLabel(title: String(localized: "Save"), busyTitle: String(localized: "Saving…"), isBusy: status.isSaving)
			}
			.keyboardShortcut(.defaultAction)
			.disabled(!draft.canSave)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.editSheetSave)
		}
	}
}
