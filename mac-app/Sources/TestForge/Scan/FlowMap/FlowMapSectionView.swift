import SwiftUI

enum FlowMapLeftPane: String, CaseIterable, Identifiable {
	case steps
	case screens

	var id: String { rawValue }
}

/// Scan › Record macro (D-171, D-174): saved macros when idle; while recording, steps or the screen tree on the left,
/// the selected screen on the right.
struct FlowMapSectionView: View {
	@ObservedObject var viewModel: FlowMapViewModel
	@State private var leftPane: FlowMapLeftPane = .steps

	var body: some View {
		VStack(spacing: 0) {
			FlowMapHeaderView(viewModel: viewModel)
			if let notice = viewModel.missingIdentifierNotice {
				MissingIdentifierBannerView(text: notice, dismiss: viewModel.dismissMissingIdentifierNotice)
			}
			Divider()
			switch viewModel.phase {
				case .library:
					SavedMacrosLibraryView(viewModel: viewModel)
				case .recording, .review:
					recordingContent
			}
		}
		.onAppear {
			viewModel.loadSavedMacros()
		}
		.confirmationDialog("Discard this recording?", isPresented: $viewModel.isDiscardConfirmationPresented) {
			Button("Discard recording", role: .destructive, action: viewModel.confirmDiscard)
				.accessibilityIdentifier(MacroRecorderConstants.Accessibility.discardConfirm)
			Button("Cancel", role: .cancel) {
				viewModel.isDiscardConfirmationPresented = false
			}
		} message: {
			Text("Its \(viewModel.recordedSteps.count) steps are thrown away. This can't be undone.")
		}
		.alert("Saved macros", isPresented: isLibraryMessagePresented) {
			Button("OK", action: viewModel.dismissLibraryMessage)
		} message: {
			Text(viewModel.libraryMessage ?? "")
		}
		.alert("Record macro", isPresented: isFailurePresented) {
			Button("OK", action: viewModel.dismissFailure)
		} message: {
			Text(failureMessage)
		}
		.sheet(item: $viewModel.saveDraft) { draft in
			SaveRecordedMacroSheetView(draft: draft) { editedDraft in
				viewModel.saveMacro(draft: editedDraft)
			} onCancel: {
				viewModel.saveDraft = nil
			}
		}
		.alert(item: $viewModel.saveOutcome) { outcome in
			Alert(title: Text(outcome.title), message: Text(outcome.message))
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.flowMap)
	}

	@ViewBuilder
	private var recordingContent: some View {
		if viewModel.map?.screens.isEmpty == false {
			HStack(spacing: 0) {
				leftColumn
					.frame(width: TestForgeConstants.FlowMap.treeWidth)
				Divider()
				detail
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
		} else {
			LoadingStateView(text: "Reading the screen on the Simulator…")
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.flowMapEmpty)
		}
	}

	private var leftColumn: some View {
		VStack(spacing: 0) {
			Picker("Show", selection: $leftPane) {
				Text("Steps (\(viewModel.recordedSteps.count))").tag(FlowMapLeftPane.steps)
				Text("Screens").tag(FlowMapLeftPane.screens)
			}
			.pickerStyle(.segmented)
			.labelsHidden()
			.padding(TestForgeConstants.Spacing.medium)
			.accessibilityIdentifier(MacroRecorderConstants.Accessibility.leftPicker)
			switch leftPane {
				case .steps:
					if let saveFailure = viewModel.mapSaveFailure {
						Label(saveFailure, systemImage: "exclamationmark.triangle.fill")
							.font(.caption)
							.foregroundStyle(.red)
							.padding(.horizontal, TestForgeConstants.Spacing.medium)
							.accessibilityIdentifier(TestForgeConstants.Accessibility.flowMapStepsSaveFailure)
					}
					RecordedStepsListView(rows: viewModel.stepRows) { stepId in
						viewModel.removeStep(id: stepId)
					} select: { screenId in
						viewModel.selectedScreenId = screenId
					}
				case .screens:
					FlowTreeView(nodes: viewModel.treeNodes, currentScreenId: viewModel.currentScreenId, selection: $viewModel.selectedScreenId)
			}
		}
	}

	@ViewBuilder
	private var detail: some View {
		if let screen = viewModel.selectedScreen {
			let model = FlowScreenDetailModel(
				screen: screen,
				thumbnailURL: viewModel.selectedThumbnailURL,
				isCurrent: screen.id == viewModel.currentScreenId,
				incoming: viewModel.incomingRows,
				outgoing: viewModel.outgoingRows,
				saveFailure: viewModel.mapSaveFailure
			)
			let actions = FlowScreenDetailActions(
				rename: { name in viewModel.rename(screenId: screen.id, to: name) },
				select: { screenId in viewModel.selectedScreenId = screenId }
			)
			FlowScreenDetailView(model: model, actions: actions)
				.id(screen.id)
		} else {
			ContentUnavailableView("Select a screen", systemImage: "rectangle.portrait.on.rectangle.portrait")
		}
	}

	private var failureMessage: String {
		if case .failed(let message) = viewModel.state {
			return message
		}
		return ""
	}

	private var isLibraryMessagePresented: Binding<Bool> {
		let viewModel = viewModel
		return Binding {
			viewModel.libraryMessage != nil
		} set: { isPresented in
			if !isPresented {
				viewModel.dismissLibraryMessage()
			}
		}
	}

	private var isFailurePresented: Binding<Bool> {
		let viewModel = viewModel
		return Binding {
			if case .failed = viewModel.state {
				return true
			}
			return false
		} set: { isPresented in
			if !isPresented {
				viewModel.dismissFailure()
			}
		}
	}
}
