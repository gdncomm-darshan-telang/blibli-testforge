import SwiftUI

struct AnnotationToolbarView: View {
	@ObservedObject var viewModel: TestCaseMediaViewModel

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Picker("Tool", selection: $viewModel.tool) {
				ForEach(AnnotationTool.allCases) { tool in
					Label { Text(tool.title) } icon: { Image(systemName: tool.systemImage) }
						.tag(tool)
				}
			}
			.pickerStyle(.segmented)
			.labelsHidden()
			.fixedSize()
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaToolPicker)
			Picker("Colour", selection: $viewModel.color) {
				ForEach(AnnotationColor.allCases) { color in
					Text(color.title).tag(color)
				}
			}
			.labelsHidden()
			.fixedSize()
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaColorPicker)
			Button("Undo", systemImage: "arrow.uturn.backward") {
				viewModel.undoStroke()
			}
			.keyboardShortcut("z", modifiers: .command)
			.disabled(viewModel.strokes.isEmpty)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaUndo)
			Button("Clear", systemImage: "trash") {
				viewModel.clearStrokes()
			}
			.disabled(viewModel.strokes.isEmpty)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaClear)
			Spacer()
			Button("Cancel") {
				viewModel.endAnnotating()
			}
			.keyboardShortcut(.cancelAction)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaCancel)
			Button("Save as copy") {
				viewModel.saveAsCopy()
			}
			.disabled(!viewModel.canSaveAnnotations)
			.help("Save the annotated screenshot as a new file beside the original")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaSaveCopy)
			Button("Save…") {
				viewModel.requestOverwrite()
			}
			.disabled(!viewModel.canSaveAnnotations)
			.help("Replace the original screenshot with the annotated one")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaSave)
		}
		.labelStyle(.iconOnly)
		.padding(.horizontal, TestForgeConstants.Spacing.medium)
		.frame(height: TestForgeConstants.ProofViewer.controlBarHeight)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaAnnotationBar)
	}
}
