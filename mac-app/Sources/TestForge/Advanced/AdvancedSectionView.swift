import SwiftUI

/// Advanced: fake data, recorded steps and the phone remote, one panel at a time.
struct AdvancedSectionView: View {
	@ObservedObject var viewModel: AdvancedSectionViewModel

	var body: some View {
		VStack(spacing: 0) {
			Picker("Panel", selection: $viewModel.selectedPanel) {
				ForEach(AdvancedPanel.allCases) { panel in
					Text(panel.title).tag(panel)
				}
			}
			.pickerStyle(.segmented)
			.labelsHidden()
			.frame(maxWidth: TestForgeConstants.Advanced.pickerMaxWidth)
			.padding(TestForgeConstants.Spacing.medium)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.advancedPanelPicker)
			.tutorialAnchor(.advancedPanelPicker)
			Divider()
			panelContent
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.advanced)
	}

	@ViewBuilder
	private var panelContent: some View {
		switch viewModel.selectedPanel {
			case .fakeData:
				FakeDataPanelView(viewModel: viewModel.fakeDataViewModel)
			case .recordedSteps:
				RecordedStepsPanelView(viewModel: viewModel.recordedStepsViewModel)
			case .phoneRemote:
				PhoneRemotePanelView(viewModel: viewModel.phoneRemoteViewModel)
		}
	}
}
