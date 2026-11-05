import SwiftUI

struct SimulatorResetSectionView: View {
	@ObservedObject var viewModel: SimulatorControlViewModel

	var body: some View {
		SimulatorCardView(card: Self.card) {
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				Button(action: viewModel.resetPrivacy) {
					SimulatorActionLabel(title: "Permissions", systemImage: "hand.raised", isBusy: viewModel.isRunning(.resetPrivacy))
				}
				.help("Forget camera, location, notification and other answers for the app above")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorResetPrivacyButton)
				Button(action: viewModel.resetKeychain) {
					SimulatorActionLabel(title: "Keychain", systemImage: "key", isBusy: viewModel.isRunning(.resetKeychain))
				}
				.help("Remove saved logins and tokens on this device")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorResetKeychainButton)
				Spacer()
				Button(role: .destructive) {
					viewModel.isEraseConfirmationShown = true
				} label: {
					SimulatorActionLabel(title: "Erase device…", systemImage: "trash", isBusy: viewModel.isRunning(.erase))
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorEraseButton)
				.tutorialAnchor(.simulatorReset)
			}
			.disabled(!viewModel.canAct)
			SimulatorCardActivityView(activity: viewModel.activity(for: .reset), card: .reset)
		}
		.confirmationDialog("Erase this device?", isPresented: $viewModel.isEraseConfirmationShown) {
			Button("Erase device", role: .destructive, action: viewModel.confirmErase)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorEraseConfirmButton)
		} message: {
			Text("Every app, its data and all settings on \(viewModel.selectedDevice?.name ?? "this device") are deleted. This can't be undone.")
		}
	}
}

private extension SimulatorResetSectionView {
	static let card = SimulatorCard(
		name: "Reset",
		title: "Reset",
		systemImage: "arrow.counterclockwise",
		tint: .orange,
		footer: "Erase removes every app and setting on the device, like a new phone; the app must be installed again."
	)
}
