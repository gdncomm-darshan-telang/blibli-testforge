import SwiftUI

struct OnboardingFooterActions {
	let back: () -> Void
	let next: () -> Void
	let skip: () -> Void
}

struct OnboardingFooterView: View {
	let canGoBack: Bool
	let isLastStep: Bool
	let actions: OnboardingFooterActions

	var body: some View {
		HStack {
			Button("Skip tour", action: actions.skip)
				.keyboardShortcut(.cancelAction)
				.accessibilityIdentifier(OnboardingConstants.Accessibility.skipButton)
			Spacer()
			Button("Back", action: actions.back)
				.disabled(!canGoBack)
				.accessibilityIdentifier(OnboardingConstants.Accessibility.backButton)
			Button(isLastStep ? "Done" : "Next", action: actions.next)
				.keyboardShortcut(.defaultAction)
				.accessibilityIdentifier(OnboardingConstants.Accessibility.nextButton)
		}
		.padding(TestForgeConstants.Spacing.large)
	}
}
