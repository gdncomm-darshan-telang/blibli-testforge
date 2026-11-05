import SwiftUI

/// Reads and changes one of the app's saved settings (UserDefaults) on the phone.
struct SimulatorDefaultsSectionView: View {
	@ObservedObject var viewModel: SimulatorControlViewModel

	var body: some View {
		SimulatorCardView(card: Self.card) {
			TextField("Key", text: $viewModel.defaultKey, prompt: Text("Key"))
				.textFieldStyle(.roundedBorder)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorDefaultKeyField)
				.tutorialAnchor(.simulatorDefaults)
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				Picker("Type", selection: $viewModel.defaultType) {
					ForEach(UserDefaultValueType.allCases) { type in
						Text(type.rawValue).tag(type)
					}
				}
				.pickerStyle(.segmented)
				.labelsHidden()
				.fixedSize()
				.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorDefaultTypePicker)
				TextField("Value", text: $viewModel.defaultValue, prompt: Text("Value"))
					.textFieldStyle(.roundedBorder)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorDefaultValueField)
			}
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				Button(action: viewModel.readDefault) {
					SimulatorActionLabel(title: "Read", systemImage: "eye", isBusy: viewModel.isRunning(.readDefault))
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorDefaultReadButton)
				Button(action: viewModel.writeDefaultAndRelaunch) {
					SimulatorActionLabel(title: "Write and relaunch", systemImage: "square.and.pencil", isBusy: viewModel.isRunning(.writeDefault))
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorDefaultWriteButton)
				Spacer()
				Button(role: .destructive, action: viewModel.deleteDefault) {
					SimulatorActionLabel(title: "Delete", systemImage: "trash", isBusy: viewModel.isRunning(.deleteDefault))
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorDefaultDeleteButton)
			}
			.disabled(!viewModel.canAct || !viewModel.hasDefaultKey)
			SimulatorCardActivityView(activity: viewModel.activity(for: .defaults), card: .defaults)
		}
	}
}

private extension SimulatorDefaultsSectionView {
	static let card = SimulatorCard(
		name: "SavedSettings",
		title: "Saved settings (UserDefaults)",
		systemImage: "gearshape.2.fill",
		tint: .teal,
		footer: "Uses the bundle id above. The app reads settings when it starts, so writing relaunches it."
	)
}
