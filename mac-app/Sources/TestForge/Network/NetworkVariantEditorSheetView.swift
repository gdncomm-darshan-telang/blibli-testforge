import SwiftUI

/// The answer editor: kind, status, delay, failure, body; Save rewrites it, Save as copy keeps the original.
struct NetworkVariantEditorSheetView: View {
	@ObservedObject var viewModel: NetworkVariantEditorViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Text(viewModel.endpoint)
				.font(.headline.monospaced())
			form
			if viewModel.kind == .respond {
				TextEditor(text: $viewModel.body)
					.font(.callout.monospaced())
					.frame(minHeight: NetworkConsoleConstants.Editor.bodyMinHeight)
					.border(.quaternary)
					.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.editorBody)
				NetworkTimeShiftView(viewModel: viewModel)
			}
			statusLine
			footer
		}
		.padding(TestForgeConstants.Spacing.large)
		.frame(width: NetworkConsoleConstants.Editor.sheetWidth, height: NetworkConsoleConstants.Editor.sheetHeight)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.editorSheet)
	}

	@ViewBuilder
	private var form: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			TextField("Name", text: $viewModel.name)
				.textFieldStyle(.roundedBorder)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.editorNameField)
			Picker("Kind", selection: $viewModel.kind) {
				ForEach(NetworkVariantKind.allCases) { kind in
					Text(kind.title).tag(kind)
				}
			}
			.fixedSize()
			.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.editorKindPicker)
		}
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			if viewModel.kind == .respond {
				Text("Status")
				TextField("200", text: $viewModel.statusCodeText)
					.textFieldStyle(.roundedBorder)
					.frame(width: NetworkConsoleConstants.Editor.numberFieldWidth)
					.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.editorStatusField)
			}
			if viewModel.kind == .fail {
				Picker("Failure", selection: $viewModel.failure) {
					ForEach(NetworkFailureKind.allCases) { failure in
						Text(failure.title).tag(failure)
					}
				}
				.fixedSize()
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.editorFailurePicker)
			}
			if viewModel.kind != .hang {
				Text("Delay")
				TextField("0", text: $viewModel.delayText)
					.textFieldStyle(.roundedBorder)
					.frame(width: NetworkConsoleConstants.Editor.numberFieldWidth)
					.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.editorDelayField)
				Text("s")
			}
			Spacer()
		}
	}

	@ViewBuilder
	private var statusLine: some View {
		if case .failed(let message) = viewModel.phase {
			Label(message, systemImage: "exclamationmark.triangle")
				.foregroundStyle(.red)
				.textSelection(.enabled)
		} else if let problem = viewModel.validationMessage {
			Label(problem, systemImage: "exclamationmark.circle")
				.foregroundStyle(.orange)
		}
	}

	@ViewBuilder
	private var footer: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Button("Delete", systemImage: "trash", role: .destructive, action: viewModel.delete)
				.disabled(viewModel.isActive)
				.help(viewModel.isActive ? Text("Choose another answer for the rule first") : Text("Delete this answer"))
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.editorDeleteButton)
			Spacer()
			if viewModel.phase == .saving {
				ProgressView()
					.controlSize(.small)
			}
			TextField("Copy name", text: $viewModel.copyName)
				.textFieldStyle(.roundedBorder)
				.frame(width: NetworkConsoleConstants.Scenarios.nameFieldWidth)
			Button("Save as copy", action: viewModel.saveAsCopy)
				.disabled(!viewModel.canSave)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.editorSaveCopyButton)
			Button("Cancel", role: .cancel, action: viewModel.cancel)
				.keyboardShortcut(.cancelAction)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.editorCancelButton)
			Button("Save", action: viewModel.save)
				.keyboardShortcut(.defaultAction)
				.disabled(!viewModel.canSave)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.editorSaveButton)
		}
	}
}
