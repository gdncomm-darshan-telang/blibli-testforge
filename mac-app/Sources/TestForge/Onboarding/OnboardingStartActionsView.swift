import SwiftUI

struct OnboardingStartActionsView: View {
	let perform: (OnboardingStartAction) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			ForEach(OnboardingStartAction.allCases) { action in
				HStack(spacing: TestForgeConstants.Spacing.medium) {
					Image(systemName: action.symbolName)
						.font(.title2)
						.foregroundStyle(Color.accentColor)
						.frame(width: OnboardingConstants.Layout.cardSymbolWidth)
					VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
						Text(action.title)
							.font(.headline)
						Text(action.text)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
					Spacer()
					Button(action.title) {
						perform(action)
					}
					.accessibilityIdentifier(OnboardingConstants.Accessibility.startActionPrefix + action.rawValue)
				}
				.padding(TestForgeConstants.Spacing.medium)
				.background(
					RoundedRectangle(cornerRadius: OnboardingConstants.Layout.cardCornerRadius)
						.fill(.quaternary.opacity(OnboardingConstants.Layout.surfaceOpacity))
				)
			}
		}
	}
}
