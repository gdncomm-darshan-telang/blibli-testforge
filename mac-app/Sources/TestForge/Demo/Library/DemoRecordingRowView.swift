import SwiftUI

/// The whole row is the click target; the list's selection opens the demo.
struct DemoRecordingRowView: View {
	let recording: DemoRecording
	let isSelected: Bool

	var body: some View {
		HStack(alignment: .top, spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: isSelected ? "play.rectangle.fill" : "play.circle.fill")
				.font(.title)
				.foregroundStyle(Color.accentColor)
				.accessibilityHidden(true)
				.accessibilityIdentifier(DemoLibraryConstants.Accessibility.rowIcon)
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(recording.macroName)
					.font(.body.weight(.medium))
					.lineLimit(2)
					.help(recording.macroName)
					.accessibilityIdentifier(DemoLibraryConstants.Accessibility.rowTitle)
				Text(detailText)
					.font(.caption)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier(DemoLibraryConstants.Accessibility.rowDetail)
				Text(languagesText)
					.font(.caption)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier(DemoLibraryConstants.Accessibility.rowLanguages)
			}
			Spacer(minLength: 0)
		}
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.contentShape(Rectangle())
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(.isButton)
		.accessibilityIdentifier(DemoLibraryConstants.Accessibility.row)
	}

	private var detailText: String {
		let date = recording.recordedAt?.formatted(date: .abbreviated, time: .shortened) ?? ""
		return [String(localized: "Case \(recording.caseId)"), recording.verdict ?? "", date]
			.filter { !$0.isEmpty }
			.joined(separator: " · ")
	}

	private var languagesText: String {
		recording.languages.map(\.title).joined(separator: " · ")
	}
}
