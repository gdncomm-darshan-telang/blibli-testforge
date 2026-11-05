import SwiftUI

struct OnboardingFlowStepView: View {
	let flowStep: OnboardingFlowStep

	var body: some View {
		HStack(alignment: .top, spacing: TestForgeConstants.Spacing.medium) {
			Text(String(flowStep.number))
				.font(.headline)
				.foregroundStyle(.white)
				.frame(width: OnboardingConstants.Layout.numberDiameter, height: OnboardingConstants.Layout.numberDiameter)
				.background(Circle().fill(Color.accentColor))
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				HStack(alignment: .firstTextBaseline) {
					Text(flowStep.title)
						.font(.headline)
					Text(flowStep.place)
						.font(.callout.monospaced())
						.foregroundStyle(.secondary)
				}
				Text(flowStep.text)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
				OnboardingClaudeMarkerView(needsClaude: flowStep.needsClaude, note: flowStep.claudeNote)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(OnboardingConstants.Accessibility.flowStepPrefix + String(flowStep.number))
	}
}
