import SwiftUI

struct ScanHeaderActions {
	let stop: () -> Void
	let showSimulator: () -> Void
}

struct ScanHeaderView: View {
	let live: ScanLiveModel
	let actions: ScanHeaderActions

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				ProgressView()
					.controlSize(.small)
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
					Text(live.title)
						.font(.headline)
					Text(live.subtitle)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				Spacer()
				Button("Show Simulator") {
					actions.showSimulator()
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.scanShowSimulatorButton)
				Button(role: .destructive) {
					actions.stop()
				} label: {
					Label("Stop scan", systemImage: "stop.fill")
				}
				.disabled(live.isStopping)
				.help("Stop and save the scan")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.scanStopButton)
			}
			if let warning = live.warning {
				Label(warning, systemImage: "exclamationmark.triangle")
					.font(.callout)
					.foregroundStyle(.orange)
			}
		}
		.padding(TestForgeConstants.Spacing.medium)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.scanHeader)
	}
}
