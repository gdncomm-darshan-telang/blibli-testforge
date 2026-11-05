import SwiftUI

struct OnboardingStepListView: View {
	let current: OnboardingStep
	let select: (OnboardingStep) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Label("TestForge", systemImage: "hammer.circle")
				.font(.headline)
				.padding(.bottom, TestForgeConstants.Spacing.medium)
			ForEach(OnboardingStep.allCases) { step in
				Button {
					select(step)
				} label: {
					HStack {
						Image(systemName: step.rawValue < current.rawValue ? "checkmark.circle.fill" : "circle")
							.foregroundStyle(step == current ? Color.accentColor : Color.secondary)
						Text(step.title)
							.fontWeight(step == current ? .semibold : .regular)
					}
					.frame(maxWidth: .infinity, alignment: .leading)
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.accessibilityIdentifier(OnboardingConstants.Accessibility.stepPrefix + String(step.rawValue))
			}
			Spacer()
		}
		.padding(TestForgeConstants.Spacing.large)
		.background(.quaternary.opacity(OnboardingConstants.Layout.surfaceOpacity))
	}
}
