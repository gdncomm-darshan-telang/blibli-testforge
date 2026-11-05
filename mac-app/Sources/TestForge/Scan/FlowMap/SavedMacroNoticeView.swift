import SwiftUI

/// Shown above the saved-macros list right after End recording saved one.
struct SavedMacroNoticeView: View {
	let outcome: RecordedMacroOutcome
	let dismiss: () -> Void

	var body: some View {
		HStack(alignment: .top, spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: "checkmark.circle.fill")
				.foregroundStyle(.green)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(outcome.title)
					.font(.headline)
				Text(outcome.message)
					.font(.callout)
					.textSelection(.enabled)
					.fixedSize(horizontal: false, vertical: true)
			}
			Spacer(minLength: TestForgeConstants.Spacing.medium)
			Button(action: dismiss) {
				Image(systemName: "xmark")
			}
			.buttonStyle(.borderless)
			.accessibilityLabel("Dismiss")
			.accessibilityIdentifier(MacroRecorderConstants.Accessibility.savedNoticeDismiss)
		}
		.padding(TestForgeConstants.Spacing.medium)
		.background(Color.green.opacity(MacroRecorderConstants.bannerBackgroundOpacity), in: bannerShape)
		.padding([.horizontal, .top], TestForgeConstants.Spacing.large)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(MacroRecorderConstants.Accessibility.savedNotice)
	}

	private var bannerShape: RoundedRectangle {
		RoundedRectangle(cornerRadius: MacroRecorderConstants.bannerCornerRadius)
	}
}
