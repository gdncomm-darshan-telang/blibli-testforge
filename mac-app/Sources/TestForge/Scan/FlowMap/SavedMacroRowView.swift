import SwiftUI

struct SavedMacroRowView: View {
	let macro: RecordedMacroSummary

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: macro.isFullyIdentified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
				.font(.title3)
				.foregroundStyle(macro.isFullyIdentified ? Color.green : Color.orange)
				.frame(width: MacroRecorderConstants.rowIconSize)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(macro.name)
					.font(.body.weight(.semibold))
					.lineLimit(2)
				Text(caption)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
		}
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.help(macro.name)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(MacroRecorderConstants.Accessibility.libraryRowPrefix + macro.id)
	}

	private var caption: String {
		let date = macro.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? ""
		let cases = macro.testCases.isEmpty ? String(localized: "no test case") : String(localized: "case \(macro.testCases.joined(separator: ", "))")
		return String(localized: "\(macro.gestureCount) steps · \(cases) · \(date)")
	}
}
