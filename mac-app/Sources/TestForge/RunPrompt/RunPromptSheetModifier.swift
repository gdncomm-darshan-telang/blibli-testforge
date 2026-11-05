import SwiftUI

/// Observes the popup view model itself, so a run's question opens the sheet whichever section is showing.
struct RunPromptSheetModifier: ViewModifier {
	@ObservedObject var viewModel: RunPromptViewModel

	func body(content: Content) -> some View {
		content
			.sheet(item: promptBinding) { prompt in
				RunPromptSheetView(viewModel: viewModel, prompt: prompt)
			}
	}

	/// Only the server closes a popup: the sheet goes away when the answer lands in the `prompts` slice.
	private var promptBinding: Binding<RunPrompt?> {
		Binding {
			viewModel.prompt
		} set: { _ in
			// The person answers with a button; a dismissed sheet would leave the run waiting unseen.
		}
	}
}

extension View {
	func runPromptSheet(viewModel: RunPromptViewModel) -> some View {
		modifier(RunPromptSheetModifier(viewModel: viewModel))
	}
}
