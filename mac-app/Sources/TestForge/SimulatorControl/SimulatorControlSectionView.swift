import SwiftUI

/// Sidebar › Simulator: control and reset the phone without Xcode or the Simulator's menus.
struct SimulatorControlSectionView: View {
	@ObservedObject var viewModel: SimulatorControlViewModel
	@EnvironmentObject private var tutorials: TutorialCoordinator

	var body: some View {
		ScrollViewReader { proxy in
			ScrollView {
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
					SimulatorDeviceSectionView(viewModel: viewModel)
						.id(Self.topId)
					SimulatorStatusSectionView(viewModel: viewModel)
					PhysicalDevicesSectionView(viewModel: viewModel.physicalDevicesViewModel)
					DeeplinksSectionView(viewModel: viewModel.deeplinksViewModel)
					LazyVGrid(columns: Self.columns, alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
						SimulatorAppSectionView(viewModel: viewModel)
						SimulatorDisplaySectionView(viewModel: viewModel)
						SimulatorDefaultsSectionView(viewModel: viewModel)
						SimulatorResetSectionView(viewModel: viewModel)
					}
				}
				.padding(TestForgeConstants.Spacing.extraLarge)
				.frame(maxWidth: TestForgeConstants.SimulatorControl.contentMaxWidth)
				.frame(maxWidth: .infinity)
			}
			.onChange(of: tutorials.activeFeature) {
				// A tip can only point at a control on screen, and this one starts at the top of the page.
				if tutorials.activeFeature == .simulatorControl {
					proxy.scrollTo(Self.topId, anchor: .top)
				}
			}
		}
		.onAppear {
			viewModel.loadDevices()
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorControl)
	}
}

private extension SimulatorControlSectionView {
	static let topId = "simulatorControlTop"
	static let columns = [
		GridItem(.adaptive(minimum: TestForgeConstants.SimulatorControl.cardMinWidth), spacing: TestForgeConstants.Spacing.large, alignment: .top)
	]
}
