import SwiftUI

/// Name the macro, link it to a test case and place it in the repo; missing accessibility IDs are listed first.
struct SaveRecordedMacroSheetView: View {
	let onSave: (RecordedMacroDraft) -> Void
	let onCancel: () -> Void
	@State private var draft: RecordedMacroDraft

	init(draft: RecordedMacroDraft, onSave: @escaping (RecordedMacroDraft) -> Void, onCancel: @escaping () -> Void) {
		self.onSave = onSave
		self.onCancel = onCancel
		_draft = State(initialValue: draft)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			Text("Save \(draft.stepCount) steps as a macro")
				.font(.headline)
			if !draft.missingIdentifierWarnings.isEmpty {
				warningSection
			}
			Form {
				TextField("Name", text: $draft.name)
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.sheetName)
				Picker("Test case", selection: $draft.caseId) {
					Text("None").tag("")
					ForEach(draft.caseOptions) { option in
						Text(option.title).lineLimit(1).tag(option.id)
					}
				}
				.accessibilityIdentifier(MacroRecorderConstants.Accessibility.sheetCase)
				TextField("Module", text: $draft.module)
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.sheetModule)
				TextField("Submodule", text: $draft.submodule)
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.sheetSubmodule)
				Toggle("Start from a fresh app launch", isOn: $draft.isFreshStart)
					.help("Replay relaunches the app first, so it starts where your recording started")
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.sheetFreshStart)
			}
			buttonRow
		}
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(width: MacroRecorderConstants.sheetWidth)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(MacroRecorderConstants.Accessibility.sheet)
	}

	private var warningSection: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Label(warningTitle, systemImage: "exclamationmark.triangle.fill")
				.font(.callout.weight(.semibold))
				.foregroundStyle(.orange)
			ScrollView {
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
					ForEach(draft.missingIdentifierWarnings, id: \.self) { warning in
						Text(warning)
							.font(.caption)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
			}
			.frame(maxHeight: MacroRecorderConstants.warningListMaxHeight)
			Text("Ask a developer to add an accessibilityIdentifier to each, then record again for a reliable macro.")
				.font(.caption)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(TestForgeConstants.Spacing.medium)
		.background(
			Color.orange.opacity(MacroRecorderConstants.bannerBackgroundOpacity),
			in: RoundedRectangle(cornerRadius: MacroRecorderConstants.bannerCornerRadius)
		)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(MacroRecorderConstants.Accessibility.sheetWarnings)
	}

	private var warningTitle: String {
		let count = draft.missingIdentifierWarnings.count
		return count == 1
			? String(localized: "1 tap has no accessibility ID")
			: String(localized: "\(count) taps have no accessibility ID")
	}

	private var buttonRow: some View {
		HStack {
			Spacer()
			Button("Cancel", role: .cancel) {
				onCancel()
			}
			.keyboardShortcut(.cancelAction)
			.accessibilityIdentifier(MacroRecorderConstants.Accessibility.sheetCancel)
			Button(draft.missingIdentifierWarnings.isEmpty ? "Save" : "Save anyway") {
				onSave(draft)
			}
			.keyboardShortcut(.defaultAction)
			.disabled(!draft.canSave)
			.accessibilityIdentifier(MacroRecorderConstants.Accessibility.sheetSave)
		}
	}
}
