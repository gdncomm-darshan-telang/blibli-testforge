import SwiftUI

/// Orange heads-up under the record bar when the last tap had no accessibility ID (D-171).
struct MissingIdentifierBannerView: View {
	let text: String
	let dismiss: () -> Void

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundStyle(.orange)
				.accessibilityHidden(true)
			Text(text)
				.font(.callout)
				.fixedSize(horizontal: false, vertical: true)
				.accessibilityIdentifier(MacroRecorderConstants.Accessibility.bannerText)
			Spacer(minLength: TestForgeConstants.Spacing.medium)
			Button(action: dismiss) {
				Image(systemName: "xmark")
			}
			.buttonStyle(.borderless)
			.help("Dismiss")
			.accessibilityLabel("Dismiss")
			.accessibilityIdentifier(MacroRecorderConstants.Accessibility.bannerDismiss)
		}
		.padding(TestForgeConstants.Spacing.medium)
		.background(
			Color.orange.opacity(MacroRecorderConstants.bannerBackgroundOpacity),
			in: RoundedRectangle(cornerRadius: MacroRecorderConstants.bannerCornerRadius)
		)
		.padding(.horizontal, TestForgeConstants.Spacing.large)
		.padding(.bottom, TestForgeConstants.Spacing.medium)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(MacroRecorderConstants.Accessibility.banner)
	}
}
