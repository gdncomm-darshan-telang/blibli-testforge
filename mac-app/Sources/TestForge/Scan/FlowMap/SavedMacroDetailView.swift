import SwiftUI

struct SavedMacroDetailActions {
	let replay: () -> Void
	let editSteps: () -> Void
	let reveal: () -> Void
}

struct SavedMacroDetailView: View {
	let macro: RecordedMacroSummary
	let isStartingReplay: Bool
	let actions: SavedMacroDetailActions

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
				Text(macro.name)
					.font(.title2.weight(.semibold))
					.textSelection(.enabled)
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.macroDetailName)
				HStack(spacing: TestForgeConstants.Spacing.medium) {
					Button(action: actions.replay) {
						if isStartingReplay {
							ActionProgressLabel(title: String(localized: "Replay"), busyTitle: String(localized: "Starting…"), isBusy: true)
						} else {
							Label("Replay", systemImage: "play.fill")
						}
					}
					.buttonStyle(.borderedProminent)
					.disabled(isStartingReplay)
					.help("Replay on the driver, without Claude")
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.macroReplay)
					Button(action: actions.editSteps) {
						Label("Edit steps…", systemImage: "list.bullet.indent")
					}
					.help("Reorder, remove or change waits and typed text, without opening the JSON")
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.macroEditSteps)
					.tutorialAnchor(.scanEditStepsButton)
					Button(action: actions.reveal) {
						Label("Show in Finder", systemImage: "folder")
					}
					.disabled(macro.path == nil)
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.macroReveal)
				}
				factRows
			}
			.padding(TestForgeConstants.Spacing.extraLarge)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(MacroRecorderConstants.Accessibility.macroDetail)
	}

	private var factRows: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			fact("Steps", value: String(localized: "\(macro.gestureCount) taps and swipes"))
			fact("Test case", value: macro.testCases.isEmpty ? String(localized: "Not linked — replay it from here") : macro.testCases.joined(separator: ", "))
			fact("Starts", value: macro.startsFresh ? String(localized: "From a fresh app launch") : String(localized: "Where the app already is"))
			fact("Recorded", value: macro.createdAt?.formatted(date: .long, time: .shortened) ?? "—")
			fact("Accessibility IDs", value: identifierText)
			if let path = macro.path {
				fact("File", value: path)
			}
		}
	}

	private var identifierText: String {
		if macro.isFullyIdentified {
			return String(localized: "Every tap is found by its ID")
		}
		var parts: [String] = []
		if macro.foundByText > 0 {
			parts.append(String(localized: "\(macro.foundByText) found by text (breaks if the copy or language changes)"))
		}
		if macro.needsPerson > 0 {
			parts.append(String(localized: "\(macro.needsPerson) need a person to tap"))
		}
		return parts.joined(separator: "; ")
	}

	private func fact(_ title: LocalizedStringKey, value: String) -> some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text(title)
				.font(.headline)
			Text(value)
				.foregroundStyle(.secondary)
				.textSelection(.enabled)
				.fixedSize(horizontal: false, vertical: true)
		}
	}
}
