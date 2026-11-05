import SwiftUI

/// Observes the export model itself, so the sheet opens without the Tests view republishing.
struct SessionExportSheetModifier: ViewModifier {
	@ObservedObject var viewModel: SessionExportViewModel

	func body(content: Content) -> some View {
		content.sheet(isPresented: $viewModel.isPresented) {
			SessionExportSheetView(viewModel: viewModel)
		}
	}
}
