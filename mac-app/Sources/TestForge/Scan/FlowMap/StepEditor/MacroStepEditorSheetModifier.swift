import SwiftUI

/// Presents the step editor from whatever view observes it, without the library view observing the editor itself.
struct MacroStepEditorSheetModifier: ViewModifier {
	@ObservedObject var editor: MacroStepEditorViewModel

	func body(content: Content) -> some View {
		content.sheet(isPresented: Binding(get: { editor.isShown }, set: { isShown in
			if !isShown {
				editor.dismiss()
			}
		})) {
			MacroStepEditorSheetView(viewModel: editor)
		}
	}
}
