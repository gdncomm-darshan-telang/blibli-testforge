import SwiftUI

/// The server accepts an override only to PASS or FAIL, with a reason of at least a few words.
struct OverrideVerdictSheetView: View {
	let model: OverrideVerdictSheetModel
	let onSave: (String, String) -> Void
	let onCancel: () -> Void

	@State private var verdict = "PASS"
	@State private var reason = ""

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			Text("Override the verdict of \(model.caseId)")
				.font(.headline)
			Picker("Verdict", selection: $verdict) {
				Text("PASS").tag("PASS")
				Text("FAIL").tag("FAIL")
			}
			.pickerStyle(.segmented)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.overrideVerdictPicker)
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text("Why? It shows in the report.")
					.font(.callout)
					.foregroundStyle(.secondary)
				TextField("Reason", text: $reason, prompt: Text("e.g. the fixture had one campaign; the app is right"), axis: .vertical)
					.lineLimit(TestForgeConstants.Results.reasonLineRange)
					.textFieldStyle(.roundedBorder)
					.labelsHidden()
					.accessibilityIdentifier(TestForgeConstants.Accessibility.overrideReasonField)
			}
			if let failure = model.failure {
				Label(failure, systemImage: "exclamationmark.triangle.fill")
					.font(.callout)
					.foregroundStyle(.red)
					.textSelection(.enabled)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.overrideFailure)
			}
			HStack {
				Spacer()
				Button("Cancel", role: .cancel) {
					onCancel()
				}
				.keyboardShortcut(.cancelAction)
				.disabled(model.isSaving)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.overrideCancelButton)
				Button {
					onSave(verdict, reason)
				} label: {
					ActionProgressLabel(title: String(localized: "Save override"), busyTitle: String(localized: "Saving…"), isBusy: model.isSaving)
				}
				.keyboardShortcut(.defaultAction)
				.disabled(!hasEnoughReason || model.isSaving)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.overrideSaveButton)
			}
		}
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(width: TestForgeConstants.Results.overrideSheetWidth)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.overrideSheet)
	}

	private var hasEnoughReason: Bool {
		reason.trimmingCharacters(in: .whitespacesAndNewlines).count >= TestForgeConstants.Results.minimumReasonLength
	}
}
