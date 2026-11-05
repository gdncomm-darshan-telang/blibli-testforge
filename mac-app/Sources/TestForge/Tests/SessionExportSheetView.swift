import SwiftUI

struct SessionExportSheetView: View {
	@ObservedObject var viewModel: SessionExportViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			Text("Export session")
				.font(.headline)
				.accessibilityIdentifier(SessionExportConstants.Accessibility.title)
			content
			buttonRow
		}
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(width: SessionExportConstants.sheetWidth)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(SessionExportConstants.Accessibility.sheet)
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.phase {
			case .loading:
				LoadingStateView(text: "Reading the session…")
					.accessibilityIdentifier(SessionExportConstants.Accessibility.progress)
			case .ready(let preview):
				readyContent(preview)
			case .exporting:
				ProgressView(viewModel.isMediaIncluded ? "Copying media and writing the zip…" : "Writing the zip…")
					.accessibilityIdentifier(SessionExportConstants.Accessibility.progress)
			case .finished(let outcome):
				Label(SessionExportViewModel.outcomeText(for: outcome), systemImage: "checkmark.circle.fill")
					.foregroundStyle(.green)
					.fixedSize(horizontal: false, vertical: true)
					.accessibilityIdentifier(SessionExportConstants.Accessibility.outcome)
			case .failed(let message):
				Label(message, systemImage: "exclamationmark.triangle.fill")
					.foregroundStyle(.orange)
					.fixedSize(horizontal: false, vertical: true)
					.accessibilityIdentifier(SessionExportConstants.Accessibility.outcome)
		}
	}

	private func readyContent(_ preview: SessionExportPreview) -> some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Text("One .zip with session.json (everything, for tools) and report.md (a table to read or paste):")
				.font(.callout)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
			ForEach(SessionExportViewModel.summaryLines(for: preview), id: \.self) { line in
				Label(line, systemImage: "checkmark")
					.font(.callout)
			}
			Toggle(viewModel.mediaToggleTitle, isOn: $viewModel.isMediaIncluded)
				.disabled(!viewModel.canIncludeMedia)
				.accessibilityIdentifier(SessionExportConstants.Accessibility.mediaToggle)
			Text("Media is each case's latest proof and its demo videos.")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}

	@ViewBuilder
	private var buttonRow: some View {
		HStack {
			Spacer()
			switch viewModel.phase {
				case .finished:
					Button("Show in Finder") {
						viewModel.revealExport()
					}
					.accessibilityIdentifier(SessionExportConstants.Accessibility.reveal)
					doneButton
				case .ready:
					Button("Cancel", role: .cancel) {
						viewModel.dismiss()
					}
					.keyboardShortcut(.cancelAction)
					.accessibilityIdentifier(SessionExportConstants.Accessibility.cancel)
					Button("Export…") {
						viewModel.export()
					}
					.keyboardShortcut(.defaultAction)
					.accessibilityIdentifier(SessionExportConstants.Accessibility.button)
				case .loading, .exporting:
					Button("Cancel", role: .cancel) {
						viewModel.dismiss()
					}
					.disabled(viewModel.phase == .exporting)
					.accessibilityIdentifier(SessionExportConstants.Accessibility.cancel)
				case .failed:
					doneButton
			}
		}
	}

	private var doneButton: some View {
		Button("Done") {
			viewModel.dismiss()
		}
		.keyboardShortcut(.defaultAction)
		.accessibilityIdentifier(SessionExportConstants.Accessibility.done)
	}
}
