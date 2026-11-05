import SwiftUI

/// Observes the demo so the main window only redraws its banner, not the whole page, as the demo moves on.
struct DemoBannerContainerView: View {
	@ObservedObject var viewModel: DemoRunViewModel

	var body: some View {
		if viewModel.phase != .idle {
			DemoBannerView(phase: viewModel.phase, actions: actions)
		}
	}

	private var actions: DemoBannerActions {
		let demo = viewModel
		return DemoBannerActions(
			continueToReports: { demo.continueToReports() },
			stop: { demo.stop() },
			isStopping: demo.isStopping
		)
	}
}
