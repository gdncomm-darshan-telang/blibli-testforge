import SwiftUI

/// D-174: the macros recorded in Scan — what you see whenever no recording is in progress.
struct SavedMacrosLibraryView: View {
	@ObservedObject var viewModel: FlowMapViewModel

	var body: some View {
		VStack(spacing: 0) {
			if let outcome = viewModel.savedNotice {
				SavedMacroNoticeView(outcome: outcome, dismiss: viewModel.dismissSavedNotice)
			}
			if viewModel.savedMacros.isEmpty {
				emptyState
			} else {
				HSplitView {
					listColumn
						.frame(
							minWidth: MacroRecorderConstants.libraryListMinWidth,
							idealWidth: MacroRecorderConstants.libraryListIdealWidth,
							maxWidth: MacroRecorderConstants.libraryListMaxWidth,
							maxHeight: .infinity
						)
					detail
						.frame(minWidth: MacroRecorderConstants.libraryDetailMinWidth, maxWidth: .infinity, maxHeight: .infinity)
				}
			}
		}
		.modifier(MacroStepEditorSheetModifier(editor: viewModel.stepEditor))
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(MacroRecorderConstants.Accessibility.library)
	}

	private var listColumn: some View {
		VStack(alignment: .leading, spacing: 0) {
			HStack {
				Label("Saved macros (\(viewModel.savedMacros.count))", systemImage: "tray.full")
					.font(.title3.weight(.semibold))
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.libraryTitle)
				Spacer()
				if viewModel.isLoadingSavedMacros {
					ProgressView()
						.controlSize(.small)
				}
				Button {
					viewModel.loadSavedMacros()
				} label: {
					Image(systemName: "arrow.clockwise")
				}
				.buttonStyle(.borderless)
				.help("Reload the list")
				.accessibilityLabel("Reload saved macros")
				.accessibilityIdentifier(MacroRecorderConstants.Accessibility.libraryRefresh)
			}
			.padding(TestForgeConstants.Spacing.large)
			List(viewModel.savedMacros, selection: $viewModel.selectedMacroId) { macro in
				SavedMacroRowView(macro: macro)
					.tag(macro.id)
			}
			.accessibilityIdentifier(MacroRecorderConstants.Accessibility.libraryList)
		}
		.tutorialAnchor(.scanSavedMacros)
	}

	@ViewBuilder
	private var detail: some View {
		if let macro = viewModel.selectedMacro {
			let actions = SavedMacroDetailActions(
				replay: viewModel.replaySelectedMacro,
				editSteps: viewModel.editSelectedMacroSteps,
				reveal: viewModel.revealSelectedMacro
			)
			SavedMacroDetailView(macro: macro, isStartingReplay: viewModel.isStartingMacroReplay, actions: actions)
				.id(macro.id)
		} else {
			ContentUnavailableView("Select a macro", systemImage: "list.bullet.rectangle")
		}
	}

	private var emptyState: some View {
		ContentUnavailableView {
			Label("No macros recorded yet", systemImage: "record.circle")
		} description: {
			Text(Self.emptyDescription)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.tutorialAnchor(.scanSavedMacros)
		.accessibilityIdentifier(MacroRecorderConstants.Accessibility.libraryEmpty)
	}
}

private extension SavedMacrosLibraryView {
	static let emptyDescription: LocalizedStringKey = """
		Press Start recording, then tap through the app in the Simulator. Each tap becomes a step, found by the accessibility ID \
		of what you tapped; you're warned when it has none. End recording to name and save it — it then appears here.
		"""
}
