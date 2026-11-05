import SwiftUI

struct OverrideResultSheetActions {
	let save: (CaseResultOverrideDraft, Bool) -> Void
	let cancel: () -> Void
}

/// D-180: the person sets a case's result with a required description; Save and rerun hands it to Claude too.
/// Stays open while saving (D-213) and closes once the server saved; a failure shows above the buttons.
struct OverrideResultSheetView: View {
	let actions: OverrideResultSheetActions
	let status: TestCaseSheetStatus
	@State private var draft: CaseResultOverrideDraft

	init(draft: CaseResultOverrideDraft, actions: OverrideResultSheetActions, status: TestCaseSheetStatus) {
		self.actions = actions
		self.status = status
		_draft = State(initialValue: draft)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			titleSection
			ScrollView {
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
					verdictSection
					EditTestCaseFieldView(title: "Why are you changing it? (required)", fieldId: "overrideReason", text: $draft.reason)
					EditTestCaseFieldView(title: "Expected result for reruns", fieldId: "overrideExpected", text: $draft.expected)
					leniencySection
					if !draft.history.isEmpty {
						historySection
					}
				}
			}
			if let failureMessage = status.failureMessage {
				Label(failureMessage, systemImage: "exclamationmark.triangle")
					.foregroundStyle(.red)
					.fixedSize(horizontal: false, vertical: true)
					.textSelection(.enabled)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideSheetFailure)
			}
			buttonRow
		}
		.disabled(status.isSaving)
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(width: TestForgeConstants.Tests.editSheetWidth, height: TestForgeConstants.Tests.overrideSheetHeight)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideSheet)
	}

	private var titleSection: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text("Override result of \(draft.id)")
				.font(.headline)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideSheetTitle)
			Text("\(draft.scenario) · now \(draft.currentVerdictText)")
				.font(.callout)
				.foregroundStyle(.secondary)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideSheetCurrent)
			Text(Self.noteText)
				.font(.callout)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideSheetNote)
		}
	}

	private static let noteText: LocalizedStringKey = """
		Every change is kept with your description, shown in the session report and carried in exported bundles. \
		A newer run replaces your result; your description still guides it.
		"""

	private var verdictSection: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text("New result")
				.font(.headline)
			Picker("New result", selection: $draft.verdict) {
				ForEach(CaseResultOverrideVerdict.allCases) { verdict in
					Text(verdict.title).tag(verdict)
				}
			}
			.pickerStyle(.segmented)
			.labelsHidden()
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideVerdictPicker)
		}
	}

	private var leniencySection: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text("How strictly reruns judge")
				.font(.headline)
			Picker("How strictly reruns judge", selection: $draft.leniency) {
				ForEach(CaseResultOverrideLeniency.allCases) { leniency in
					Text(leniency.title).tag(leniency)
				}
			}
			.pickerStyle(.segmented)
			.labelsHidden()
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideLeniencyPicker)
			Text(draft.leniency.explanation)
				.font(.caption)
				.foregroundStyle(.secondary)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideLeniencyNote)
		}
	}

	private var historySection: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Text("Earlier changes")
				.font(.headline)
			ForEach(draft.history) { row in
				ResultOverrideHistoryRowView(row: row)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideHistory)
	}

	private var buttonRow: some View {
		HStack {
			Spacer()
			Button("Cancel", role: .cancel) {
				actions.cancel()
			}
			.keyboardShortcut(.cancelAction)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideSheetCancel)
			Button {
				actions.save(draft, false)
			} label: {
				ActionProgressLabel(
					title: String(localized: "Save"),
					busyTitle: String(localized: "Saving…"),
					isBusy: status.savingAction == .saveOverride
				)
			}
			.disabled(!draft.canSave)
			.help("Record the new result only")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideSheetSave)
			Button {
				actions.save(draft, true)
			} label: {
				ActionProgressLabel(
					title: String(localized: "Save and rerun"),
					busyTitle: String(localized: "Saving and starting…"),
					isBusy: status.savingAction == .overrideAndRerun
				)
			}
			.keyboardShortcut(.defaultAction)
			.disabled(!draft.canSave)
			.help("Record the result, then Claude reruns the case with this expected result, leniency and your description")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsOverrideSheetSaveRerun)
		}
	}
}
