import SwiftUI

struct DemoBannerActions {
	let continueToReports: () -> Void
	let stop: () -> Void

	/// D-213: set while the stop request is out, so Stop shows "Stopping…" and can't be pressed twice.
	let isStopping: Bool
}

/// A strip above the screen that says which demo step this is and what to do next.
struct DemoBannerView: View {
	let phase: DemoPhase
	let actions: DemoBannerActions

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: symbolName)
				.foregroundStyle(.tint)
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(title)
					.font(.headline)
				Text(message)
					.font(.callout)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
			Spacer()
			buttons
		}
		.padding(TestForgeConstants.Spacing.medium)
		.background(.tint.opacity(TestForgeConstants.Demo.bannerTintOpacity))
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.demoBanner)
	}

	@ViewBuilder
	private var buttons: some View {
		switch phase {
			case .reviewingResults:
				Button("Next: Reports", action: actions.continueToReports)
					.buttonStyle(.borderedProminent)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.demoNextButton)
				closeButton(title: "End demo")
			case .starting, .running:
				Button(action: actions.stop) {
					ActionProgressLabel(title: String(localized: "Stop demo"), busyTitle: String(localized: "Stopping…"), isBusy: actions.isStopping)
				}
				.disabled(actions.isStopping)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.demoStopButton)
			case .idle, .blocked, .finished, .failed:
				closeButton(title: "Close")
		}
	}

	private func closeButton(title: LocalizedStringKey) -> some View {
		Button(title, action: actions.stop)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.demoStopButton)
	}

	private var symbolName: String {
		switch phase {
			case .blocked, .failed:
				return "exclamationmark.triangle"
			case .finished:
				return "checkmark.seal"
			case .idle, .starting, .running, .reviewingResults:
				return "play.rectangle"
		}
	}

	private var title: LocalizedStringKey {
		switch phase {
			case .idle:
				return "Demo run"
			case .blocked:
				return "Demo can't start yet"
			case .starting:
				return "Demo 1 of 3 · Starting the tests"
			case .running:
				return "Demo 1 of 3 · Two recorded tests are running"
			case .reviewingResults:
				return "Demo 2 of 3 · Results"
			case .finished:
				return "Demo 3 of 3 · Reports"
			case .failed:
				return "Demo stopped"
		}
	}

	private var message: String {
		switch phase {
			case .idle:
				return ""
			case .blocked(let reason):
				return reason
			case .starting, .running:
				return String(localized: "SF-001 and SF-006 replay their recorded steps on the phone; no Claude is used. Watch each step on the right.")
			case .reviewingResults:
				return String(localized: "Each test's verdict, its steps and the screenshots taken are here. Follow the tips, then go to Reports.")
			case .finished:
				return String(localized: "That is the whole flow. Pick your own tests in Tests to start.")
			case .failed(let message):
				return message
		}
	}
}
