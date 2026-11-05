import SwiftUI

struct OnboardingCardView: View {
	let card: OnboardingCard

	var body: some View {
		HStack(alignment: .top, spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: card.symbolName)
				.font(.title2)
				.foregroundStyle(Color.accentColor)
				.frame(width: OnboardingConstants.Layout.cardSymbolWidth)
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(card.title)
					.font(.headline)
				Text(card.text)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.padding(TestForgeConstants.Spacing.large)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.background(
			RoundedRectangle(cornerRadius: OnboardingConstants.Layout.cardCornerRadius)
				.fill(.quaternary.opacity(OnboardingConstants.Layout.surfaceOpacity))
		)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(OnboardingConstants.Accessibility.cardPrefix + card.symbolName)
	}
}
