import SwiftUI

/// Hosts the tour sheet; it observes the tour itself, since the TestForge's own view doesn't re-render on its changes.
struct OnboardingSheetModifier<ViewModel: OnboardingPresenting>: ViewModifier {
	@ObservedObject var viewModel: ViewModel

	func body(content: Content) -> some View {
		content
			.sheet(isPresented: $viewModel.isPresented) {
				OnboardingView(viewModel: viewModel)
			}
	}
}
