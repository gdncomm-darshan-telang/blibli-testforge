import SwiftUI

struct RecordedStepRowView: View {
	let row: RecordedStepRowModel
	let remove: () -> Void

	var body: some View {
		HStack(alignment: .top, spacing: TestForgeConstants.Spacing.medium) {
			Text("\(row.number)")
				.font(.callout.monospacedDigit())
				.foregroundStyle(.secondary)
			Image(systemName: row.symbolName)
				.foregroundStyle(row.warningText == nil ? Color.accentColor : .orange)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(row.actionText)
					.lineLimit(2)
				Text(row.screenText)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
				if let warningText = row.warningText {
					Label(warningText, systemImage: "exclamationmark.triangle.fill")
						.font(.caption)
						.foregroundStyle(.orange)
						.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepWarningPrefix + "\(row.number)")
				}
			}
			Spacer(minLength: 0)
			Button(action: remove) {
				Image(systemName: "trash")
			}
			.buttonStyle(.borderless)
			.help("Leave this step out of the macro")
			.accessibilityLabel("Delete step \(row.number)")
			.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepDeletePrefix + "\(row.number)")
		}
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepPrefix + "\(row.number)")
	}
}
