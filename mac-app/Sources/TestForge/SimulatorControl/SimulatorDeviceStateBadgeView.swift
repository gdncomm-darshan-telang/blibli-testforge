import SwiftUI

struct SimulatorDeviceStateBadgeView: View {
	let isBooted: Bool

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.small) {
			Circle()
				.fill(tint)
				.frame(width: TestForgeConstants.SimulatorControl.stateDotSize, height: TestForgeConstants.SimulatorControl.stateDotSize)
			Text(isBooted ? "Booted" : "Shut down")
				.font(.caption.weight(.semibold))
		}
		.padding(.horizontal, TestForgeConstants.Spacing.medium)
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.foregroundStyle(tint)
		.background(Capsule().fill(tint.opacity(TestForgeConstants.SimulatorControl.stateBadgeOpacity)))
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorStateBadge)
	}

	private var tint: Color {
		isBooted ? .green : .secondary
	}
}
