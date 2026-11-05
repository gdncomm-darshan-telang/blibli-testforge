import SwiftUI

struct VerifyChangesSheetModifier: ViewModifier {
	@ObservedObject var viewModel: VerifyChangesViewModel

	func body(content: Content) -> some View {
		content.sheet(isPresented: Binding(get: { viewModel.isShown }, set: { isShown in
			if !isShown {
				viewModel.dismiss()
			}
		})) {
			VerifyChangesSheetView(viewModel: viewModel)
		}
	}
}
