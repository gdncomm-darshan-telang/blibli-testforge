import SwiftUI

/// Why buttons are locked, and results of the controls without a card line of their own (Display, Copy UDID).
struct SimulatorStatusSectionView: View {
	@ObservedObject var viewModel: SimulatorControlViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			if viewModel.isLocked {
				Label("A test or scan is using the phone. These controls unlock when it finishes.", systemImage: "lock.fill")
					.foregroundStyle(.orange)
			}
			if let result = viewModel.lastResult,
				result.action == nil {
				Label {
					Text("\(result.title): \(result.message)")
						.textSelection(.enabled)
						.lineLimit(TestForgeConstants.SimulatorControl.resultLineLimit)
				} icon: {
					Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
						.foregroundStyle(result.isSuccess ? Color.green : Color.orange)
				}
			} else {
				Label("Every button runs one simulator command; the console shows it and its output.", systemImage: "terminal")
					.foregroundStyle(.secondary)
			}
		}
		.font(.callout)
		.padding(.horizontal, TestForgeConstants.Spacing.large)
		.padding(.vertical, TestForgeConstants.Spacing.medium)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			RoundedRectangle(cornerRadius: TestForgeConstants.SimulatorControl.cardCornerRadius)
				.fill(Color.primary.opacity(TestForgeConstants.SimulatorControl.cardBorderOpacity / 2))
		)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorStatus)
	}
}
