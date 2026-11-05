import SwiftUI

struct ScanIdleActions {
	let start: () -> Void
	let reveal: () -> Void
	let showSimulator: () -> Void
}

struct ScanIdleView: View {
	let lastScan: ScanSummaryModel?
	let isStarting: Bool
	let actions: ScanIdleActions

	var body: some View {
		VStack(spacing: 0) {
			EmptyStateView(content: Self.introContent) {
				HStack(spacing: TestForgeConstants.Spacing.medium) {
					Button {
						actions.start()
					} label: {
						if isStarting {
							ActionProgressLabel(title: String(localized: "Start scan"), busyTitle: String(localized: "Starting…"), isBusy: true)
						} else {
							Label("Start scan", systemImage: "viewfinder")
						}
					}
					.buttonStyle(.borderedProminent)
					.disabled(isStarting)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.scanStartButton)
					.tutorialAnchor(.scanStartButton)
					Button("Show Simulator") {
						actions.showSimulator()
					}
					.accessibilityIdentifier(TestForgeConstants.Accessibility.scanShowSimulatorButton)
				}
			}
			if let lastScan {
				Divider()
				lastScanSection(summary: lastScan)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.scanIdle)
		.tutorialAnchor(.scanSection)
	}

	private static let introContent = EmptyStateContent(
		title: "Scan the app by hand",
		systemImage: "viewfinder",
		message: "You navigate the app in the Simulator; the scan watches each screen. Name a screen and mark it to save what's on it."
	)

	private func lastScanSection(summary: ScanSummaryModel) -> some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			HStack {
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
					Text(summary.title)
						.font(.headline)
					Text(summary.detail)
						.font(.callout)
						.foregroundStyle(.secondary)
				}
				Spacer()
				if summary.outURL != nil {
					Button("Show in Finder") {
						actions.reveal()
					}
					.accessibilityIdentifier(TestForgeConstants.Accessibility.scanRevealButton)
				}
			}
			if let failure = summary.failure {
				Label(failure, systemImage: "exclamationmark.triangle")
					.foregroundStyle(.orange)
			}
			ScanScreenListView(screens: summary.screens)
				.frame(maxHeight: TestForgeConstants.Scan.lastScanListMaxHeight)
		}
		.padding(TestForgeConstants.Spacing.large)
	}
}
