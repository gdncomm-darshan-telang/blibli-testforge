import SwiftUI

/// Scan › Edit steps (D-195): drag to reorder, remove, change waits and text — saved straight to the macro's file.
struct MacroStepEditorSheetView: View {
	@ObservedObject var viewModel: MacroStepEditorViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			Text("Edit steps · \(viewModel.macroName)")
				.font(.title3.weight(.semibold))
			content
			buttons
		}
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(width: MacroRecorderConstants.StepEditor.width)
		.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepEditorSheet)
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.state {
			case .hidden, .loading:
				LoadingStateView(text: "Reading the macro’s steps…")
			case .saving:
				LoadingStateView(text: "Saving to the macro file…")
			case .failed(let message):
				Label(message, systemImage: "exclamationmark.triangle")
					.foregroundStyle(.red)
					.textSelection(.enabled)
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepEditorStatus)
			case .editing:
				stepList
		}
	}

	private var stepList: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			List {
				ForEach(Array($viewModel.steps.enumerated()), id: \.element.id) { index, $step in
					EditableStepRowView(step: $step, position: index + 1) {
						viewModel.remove(stepId: step.id)
					}
				}
				.onMove(perform: viewModel.move)
			}
			.frame(height: MacroRecorderConstants.StepEditor.listHeight)
			.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepEditorList)
			Text(statusText)
				.font(.caption)
				.foregroundStyle(.secondary)
				.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepEditorStatus)
		}
	}

	private var statusText: String {
		guard viewModel.hasChanges else {
			return String(localized: "Drag a step to move it. Element references stay as recorded.")
		}
		if viewModel.removedCount > 0 {
			return String(localized: "Unsaved changes · \(viewModel.removedCount) step(s) removed")
		}
		return String(localized: "Unsaved changes")
	}

	private var buttons: some View {
		HStack {
			Button("Revert", action: viewModel.revert)
				.disabled(!viewModel.hasChanges || viewModel.state != .editing)
				.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepEditorRevert)
			if case .failed = viewModel.state {
				Button("Try again", action: viewModel.retry)
			}
			Spacer()
			Button("Cancel", role: .cancel, action: viewModel.dismiss)
				.keyboardShortcut(.cancelAction)
				.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepEditorCancel)
			Button("Save", action: viewModel.save)
				.keyboardShortcut(.defaultAction)
				.disabled(!viewModel.canSave)
				.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepEditorSave)
		}
	}
}
