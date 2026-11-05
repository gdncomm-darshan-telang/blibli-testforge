import SwiftUI

struct SimulatorAppSectionView: View {
	@ObservedObject var viewModel: SimulatorControlViewModel

	var body: some View {
		SimulatorCardView(card: Self.card) {
			TextField("Bundle id", text: $viewModel.bundleId, prompt: Text(SimulatorControlViewModel.defaultBundleId))
				.textFieldStyle(.roundedBorder)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorBundleField)
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				Button(action: viewModel.relaunchApp) {
					SimulatorActionLabel(title: "Relaunch", systemImage: "arrow.clockwise.circle", isBusy: viewModel.isRunning(.relaunchApp))
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorRelaunchButton)
				.tutorialAnchor(.simulatorAppControls)
				Button(action: viewModel.killApp) {
					SimulatorActionLabel(title: "Kill", systemImage: "xmark.octagon", isBusy: viewModel.isRunning(.killApp))
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorKillButton)
			}
			.disabled(!viewModel.canAct)
			SimulatorCardActivityView(activity: viewModel.activity(for: .app), card: .app)
		}
	}
}

private extension SimulatorAppSectionView {
	static let card = SimulatorCard(name: "App", title: "App", systemImage: "app.badge.fill", tint: .green, footer: nil)
}
