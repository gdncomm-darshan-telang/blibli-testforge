import SwiftUI

/// Simulator › Real devices (D-197): pick a paired iPhone to see whether tests can run on it and what's missing.
struct PhysicalDevicesSectionView: View {
	@ObservedObject var viewModel: PhysicalDevicesViewModel

	var body: some View {
		SimulatorCardView(card: Self.card) {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
				header
				content
			}
		}
		.onAppear {
			viewModel.load()
		}
		.tutorialAnchor(.simulatorPhysicalDevices)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.physicalDevices)
	}

	private var header: some View {
		HStack {
			Text("iPhones and iPads paired with this Mac")
				.foregroundStyle(.secondary)
			Spacer()
			Button {
				viewModel.load(isFresh: true)
			} label: {
				Image(systemName: "arrow.clockwise")
			}
			.buttonStyle(.borderless)
			.help("Look for devices again")
			.accessibilityLabel("Refresh devices")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.physicalDevicesRefresh)
		}
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.state {
			case .loading:
				LoadingStateView(text: "Looking for devices…")
			case .failed(let message):
				Label(message, systemImage: "exclamationmark.triangle.fill")
					.foregroundStyle(.orange)
			case .loaded where viewModel.rows.isEmpty:
				Text("No device is paired with this Mac. Connect one by cable and trust this Mac.")
					.foregroundStyle(.secondary)
			case .loaded:
				deviceList
		}
	}

	private var deviceList: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Picker("Device", selection: $viewModel.selectedId) {
				ForEach(viewModel.rows) { row in
					PhysicalDeviceRowView(row: row)
						.tag(String?.some(row.id))
				}
			}
			.pickerStyle(.radioGroup)
			.labelsHidden()
			.accessibilityIdentifier(TestForgeConstants.Accessibility.physicalDevicePicker)
			if let device = viewModel.selectedDevice {
				blockers(for: device)
			}
		}
	}

	private func blockers(for device: PhysicalDevice) -> some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text(device.canRunTests ? "Tests can run on \(device.name)" : "Before tests can run on \(device.name):")
				.font(.callout.weight(.semibold))
			ForEach(device.blockers, id: \.self) { blocker in
				Label(blocker, systemImage: "circle")
					.font(.callout)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
			Button("Use for tests") {
				// No action yet: the server has no way to run on hardware, so the button is always disabled (D-197).
			}
			.disabled(true)
			.help("Not available yet: tests run on simulators only. A real device needs a device-signed QA build and test runner first.")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.physicalDeviceUseButton)
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.physicalDeviceBlockers)
	}
}

private extension PhysicalDevicesSectionView {
	static let card = SimulatorCard(name: "Real devices", title: nil, systemImage: "iphone.gen3", tint: .indigo, footer: nil)
}
