import SwiftUI

/// Toolbar pill: the active Test Batch, or what to do before tests can run.
struct TestBatchToolbarView<ViewModel: TestBatchPresenting>: View {
	@ObservedObject var viewModel: ViewModel

	var body: some View {
		// A stable container, so swapping the menu for the progress pill never dismisses the sheet it presents.
		ZStack {
			if let workingTitle = viewModel.workingTitle {
				progressPill(title: workingTitle)
			} else {
				menu
			}
		}
		.sheet(isPresented: $viewModel.isStartSheetShown) {
			TestBatchStartSheetView(viewModel: viewModel)
		}
		.confirmationDialog("End this Test Batch?", isPresented: $viewModel.isEndConfirmationShown) {
			Button("End and write report", action: viewModel.confirmEnd)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchEndConfirmButton)
		} message: {
			Text("""
				Its report.md is written into the batch folder. Tests can't run again until you start, resume or reopen \
				a Test Batch. To switch to other work and come back, Pause instead.
				""")
		}
		.confirmationDialog(reopenTitle, isPresented: isReopenConfirmationShown, presenting: viewModel.pendingReopen) { _ in
			Button("Reopen", action: viewModel.confirmReopen)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchReopenConfirmButton)
		} message: { batch in
			Text(reopenMessage(batch: batch))
		}
		.alert(failureTitle, isPresented: isFailureAlertShown) {
			Button("OK", action: viewModel.dismissFailure)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchFailureAlertButton)
		} message: {
			Text(viewModel.failureMessage ?? "")
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchPill)
		.tutorialAnchor(.testBatchToolbar)
	}

	private var menu: some View {
		Menu {
			menuItems
		} label: {
			Label {
				Text(title)
			} icon: {
				Image(systemName: symbolName)
			}
			.labelStyle(.titleAndIcon)
		}
		.help(Text(helpText))
	}

	/// D-213: a menu label can't show a spinner, so the pill turns into one while its request runs; no second click meanwhile.
	private func progressPill(title: String) -> some View {
		HStack(spacing: TestForgeConstants.Spacing.small) {
			ProgressView()
				.controlSize(.small)
			Text(title)
				.lineLimit(1)
		}
		.padding(.horizontal, TestForgeConstants.Spacing.small)
		.help(Text(title))
		.accessibilityElement(children: .combine)
		.accessibilityLabel(title)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchPillProgress)
	}

	@ViewBuilder
	private var menuItems: some View {
		switch viewModel.pillState {
			case .loading:
				Text("Waiting for the server…")
			case .needsProofFolder:
				Button("Choose proof folder…", action: viewModel.chooseProofFolder)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchChooseFolderItem)
			case .noBatch:
				Button("Start Test Batch…", action: viewModel.requestStart)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchStartItem)
				resumeMenu
				Button("Show proof folder", action: viewModel.revealFolder)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchRevealItem)
				reopenMenu
				Divider()
				Button("Change proof folder…", action: viewModel.chooseProofFolder)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchChooseFolderItem)
			case .active:
				Button("Pause Test Batch", systemImage: "pause.circle", action: viewModel.pause)
					.help("Set this batch aside to work on something else; resume it later with everything it holds")
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchPauseItem)
				Button("Start another Test Batch…", action: viewModel.requestStart)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchStartAnotherItem)
				resumeMenu
				Button("End Test Batch…", action: viewModel.requestEnd)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchEndItem)
				Button("Show batch folder", action: viewModel.revealFolder)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchRevealItem)
				reopenMenu
		}
		if let failureMessage = viewModel.failureMessage {
			Divider()
			Label(failureMessage, systemImage: "exclamationmark.triangle")
		}
	}

	@ViewBuilder
	private var resumeMenu: some View {
		if !viewModel.pausedBatches.isEmpty {
			Menu("Resume Test Batch") {
				ForEach(viewModel.pausedBatches) { batch in
					Button(resumeItemTitle(batch: batch)) {
						viewModel.resume(batch: batch)
					}
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchResumeItemPrefix + batch.id)
				}
			}
			.help("Pick a paused batch up again; the active one is paused in its place")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchResumeMenu)
		}
	}

	@ViewBuilder
	private var reopenMenu: some View {
		if !viewModel.reopenableBatches.isEmpty {
			Menu("Reopen Test Batch") {
				ForEach(viewModel.reopenableBatches) { batch in
					Button(reopenItemTitle(batch: batch)) {
						viewModel.requestReopen(batch: batch)
					}
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchReopenItemPrefix + batch.id)
				}
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchReopenMenu)
		}
	}

	private var isFailureAlertShown: Binding<Bool> {
		Binding(
			get: { viewModel.isFailureAlertShown },
			set: { isShown in
				if !isShown {
					viewModel.dismissFailure()
				}
			}
		)
	}

	private var failureTitle: String {
		String(localized: "The Test Batch action didn't work")
	}

	private var isReopenConfirmationShown: Binding<Bool> {
		Binding(
			get: { viewModel.pendingReopen != nil },
			set: { isShown in
				if !isShown {
					viewModel.pendingReopen = nil
				}
			}
		)
	}

	private var reopenTitle: String {
		String(localized: "Reopen “\(viewModel.pendingReopen?.name ?? "")”?")
	}

	private func reopenItemTitle(batch: TestBatchSummary) -> String {
		let endedText = batch.endedAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? ""
		return String(localized: "\(batch.name) · \(batch.itemCount) items · ended \(endedText)")
	}

	private func resumeItemTitle(batch: TestBatchSummary) -> String {
		let pausedText = batch.pausedAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? ""
		return String(localized: "\(batch.name) · \(batch.itemCount) items · paused \(pausedText)")
	}

	private func reopenMessage(batch: TestBatchSummary) -> String {
		guard case .active(let active, _) = viewModel.pillState else {
			return String(localized: "New runs and their proof join “\(batch.name)” and its folder again.")
		}
		return String(localized: "“\(active.name)” is paused first. New runs and their proof then join “\(batch.name)” again.")
	}

	private var title: String {
		switch viewModel.pillState {
			case .loading:
				return String(localized: "Test Batch")
			case .needsProofFolder:
				return String(localized: "Choose proof folder")
			case .noBatch:
				let pausedCount = viewModel.pausedBatches.count
				return pausedCount > 0 ? String(localized: "No Test Batch · \(pausedCount) paused") : String(localized: "No Test Batch")
			case .active(let batch, _):
				return String(localized: "\(batch.name) · \(batch.itemCount)")
		}
	}

	private var symbolName: String {
		if viewModel.failureMessage != nil {
			return "exclamationmark.triangle.fill"
		}
		switch viewModel.pillState {
			case .loading:
				return "tray"
			case .noBatch:
				return viewModel.pausedBatches.isEmpty ? "exclamationmark.triangle" : "pause.circle"
			case .needsProofFolder:
				return "exclamationmark.triangle"
			case .active:
				return "tray.full"
		}
	}

	private var helpText: String {
		if let failureMessage = viewModel.failureMessage {
			return String(localized: "Last action failed: \(failureMessage)")
		}
		switch viewModel.pillState {
			case .loading:
				return ""
			case .needsProofFolder:
				return String(localized: "Tests can't run until you choose where proof and reports go.")
			case .noBatch(let proofRoot):
				return String(localized: "Tests can't run until a Test Batch is started or resumed. Proof folder: \(proofRoot)")
			case .active(let batch, let proofRoot):
				return String(localized: "Everything you run is collected in “\(batch.name)” → \(proofRoot)/\(batch.folder)")
		}
	}
}
