import SwiftUI

struct ScanMarkActions {
	let mark: () -> Void
	let skip: () -> Void
}

struct ScanMarkBarView: View {
	@Binding var screenName: String
	let model: ScanMarkBarModel
	let actions: ScanMarkActions

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				TextField("Screen name, e.g. Cart — empty", text: $screenName)
					.textFieldStyle(.roundedBorder)
					.onSubmit {
						actions.mark()
					}
					.accessibilityIdentifier(TestForgeConstants.Accessibility.scanNameField)
				Button {
					actions.mark()
				} label: {
					ActionProgressLabel(title: String(localized: "Mark"), busyTitle: String(localized: "Marking…"), isBusy: model.isMarking)
				}
				.buttonStyle(.borderedProminent)
				.keyboardShortcut(.defaultAction)
				.disabled(!model.canMark)
				.help("Record what's on screen under this name; mark the same name again for another state of it")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.scanMarkButton)
				Button {
					actions.skip()
				} label: {
					ActionProgressLabel(title: String(localized: "Skip"), busyTitle: String(localized: "Skipping…"), isBusy: model.isSkipping)
				}
				.disabled(model.isMarking || model.isSkipping)
				.help("Passing through; nothing is recorded")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.scanSkipButton)
			}
			if let confirmation = model.confirmation {
				Label(confirmation, systemImage: "checkmark.circle")
					.font(.caption)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.scanMarkConfirmation)
			}
		}
		.padding(TestForgeConstants.Spacing.medium)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.scanMarkBar)
	}
}
