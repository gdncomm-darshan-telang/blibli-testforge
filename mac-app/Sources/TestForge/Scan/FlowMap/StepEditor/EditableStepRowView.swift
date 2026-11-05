import SwiftUI

/// One step in the editor: what it does, the values a person may change, and Remove.
struct EditableStepRowView: View {
	@Binding var step: MacroStep
	let position: Int
	let remove: () -> Void

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: "line.3.horizontal")
				.foregroundStyle(.tertiary)
				.accessibilityHidden(true)
			Text("\(position).")
				.monospacedDigit()
				.foregroundStyle(.secondary)
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(step.text)
					.fixedSize(horizontal: false, vertical: true)
				editors
			}
			Spacer(minLength: 0)
			Button(role: .destructive, action: remove) {
				Image(systemName: "trash")
			}
			.buttonStyle(.borderless)
			.help("Remove this step")
			.accessibilityLabel("Remove step \(position)")
			.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepEditorRemovePrefix + step.id)
		}
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepEditorRowPrefix + step.id)
	}

	@ViewBuilder
	private var editors: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			if step.canChangeTimeout {
				numberField("Wait up to", value: $step.timeout, unit: "s")
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepEditorTimeoutPrefix + step.id)
			}
			if step.canChangeSeconds {
				numberField("Pause", value: $step.seconds, unit: "s")
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepEditorTimeoutPrefix + step.id)
			}
			if step.canChangeOptional {
				Toggle("Skip if not there", isOn: $step.isOptional)
					.toggleStyle(.checkbox)
					.help("An optional step that finds nothing is skipped instead of failing the run")
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepEditorOptionalPrefix + step.id)
			}
			if step.canChangeText {
				TextField("Text to type", text: textBinding($step.typedText))
					.textFieldStyle(.roundedBorder)
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepEditorTextPrefix + step.id)
			}
			if step.canChangeName {
				TextField("Screenshot name", text: textBinding($step.name))
					.textFieldStyle(.roundedBorder)
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepEditorTextPrefix + step.id)
			}
		}
		.font(.callout)
	}

	private func numberField(_ title: LocalizedStringKey, value: Binding<Double?>, unit: String) -> some View {
		HStack(spacing: TestForgeConstants.Spacing.small) {
			Text(title)
				.foregroundStyle(.secondary)
			TextField(title, value: value, format: .number)
				.labelsHidden()
				.textFieldStyle(.roundedBorder)
				.frame(width: MacroRecorderConstants.StepEditor.numberFieldWidth)
			Text(unit)
				.foregroundStyle(.secondary)
		}
	}

	private func textBinding(_ value: Binding<String?>) -> Binding<String> {
		Binding(get: { value.wrappedValue ?? "" }, set: { value.wrappedValue = $0 })
	}
}
