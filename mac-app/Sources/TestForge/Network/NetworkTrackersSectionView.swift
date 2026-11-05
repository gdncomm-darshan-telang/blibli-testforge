import SwiftUI

/// Trackers tab: the ask bar (IDs, contract, launches, Check, report), the per-ID list, the selected ID's fires.
struct NetworkTrackersSectionView<ViewModel: NetworkTrackersPresenting>: View {
	@ObservedObject var viewModel: ViewModel

	var body: some View {
		VStack(spacing: 0) {
			askBar
			Divider()
			HStack(spacing: 0) {
				trackerList
					.frame(width: NetworkConsoleConstants.Trackers.listWidth)
				Divider()
				firesPane
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.trackers)
	}

	@ViewBuilder
	private var askBar: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			TextField("TRMS IDs, comma separated — empty lists everything that fired", text: $viewModel.idsText)
				.textFieldStyle(.roundedBorder)
				.frame(minWidth: NetworkConsoleConstants.Trackers.idsFieldMinWidth)
				.onSubmit(viewModel.check)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.trackerIdsField)
			contractControls
			Toggle("All launches", isOn: $viewModel.isAllSessions)
				.toggleStyle(.checkbox)
				.help("Off: only the most recent app launch counts")
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.trackerAllSessionsToggle)
			Button("Check", systemImage: "checkmark.seal", action: viewModel.check)
				.keyboardShortcut(.defaultAction)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.trackerCheckButton)
			reportMenu
		}
		.padding(TestForgeConstants.Spacing.medium)
	}

	@ViewBuilder
	private var reportMenu: some View {
		if let running = viewModel.runningReport {
			HStack(spacing: TestForgeConstants.Spacing.small) {
				ProgressView()
					.controlSize(.small)
				Text(running == .copy ? String(localized: "Copying report…") : String(localized: "Saving report…"))
			}
			.accessibilityElement(children: .combine)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.networkTrackerReportProgress)
		} else {
			Menu("Report", systemImage: "doc.text") {
				Button("Copy as markdown", action: viewModel.copyReport)
					.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.trackerCopyReportButton)
				Button("Save as…", action: viewModel.saveReport)
					.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.trackerSaveReportButton)
			}
			.fixedSize()
			.help("The DA-format tracker validation page")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.networkTrackerReportMenu)
		}
		if let result = viewModel.reportResult {
			Label(result.message, systemImage: result.isSuccess ? "checkmark.circle" : "exclamationmark.triangle")
				.font(.caption)
				.lineLimit(1)
				.truncationMode(.middle)
				.foregroundStyle(result.isSuccess ? Color.secondary : Color.red)
				.help(result.message)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.networkTrackerReportResult)
		}
	}

	@ViewBuilder
	private var contractControls: some View {
		if let contractName = viewModel.contractName {
			Label(contractName, systemImage: "doc.badge.gearshape")
				.font(.callout)
				.lineLimit(1)
			Button("Remove contract", systemImage: "xmark.circle.fill", action: viewModel.clearContract)
				.labelStyle(.iconOnly)
				.buttonStyle(.borderless)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.trackerClearContractButton)
		} else {
			Button("Contract…", systemImage: "doc.badge.plus", action: viewModel.chooseContract)
				.help("A JSON file of expected payload rules per TRMS ID")
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.trackerContractButton)
		}
	}

	@ViewBuilder
	private var trackerList: some View {
		if let display = viewModel.state.content {
			VStack(alignment: .leading, spacing: 0) {
				summary(for: display)
				Divider()
				let indexedRows = Array(display.rows.enumerated())
				List(selection: $viewModel.selectedTrackerId) {
					ForEach(indexedRows, id: \.element.id) { index, tracker in
						NetworkTrackerRowView(tracker: tracker, index: index)
							.tag(tracker.id)
					}
				}
				.listStyle(.inset)
			}
		} else if viewModel.state == .notLoaded {
			NetworkPlaceholderView(phase: .empty(String(localized: "Type the TRMS IDs to validate (or none), then Check")))
		} else if let phase = NetworkPlaceholderPhase(state: viewModel.state) {
			NetworkPlaceholderView(phase: phase)
		}
	}

	@ViewBuilder
	private func summary(for display: TrackersDisplayModel) -> some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text(display.headline)
				.font(.headline)
			if let unexpectedText = display.unexpectedText {
				Text(unexpectedText)
					.font(.caption)
					.foregroundStyle(.secondary)
					.textSelection(.enabled)
			}
			if let contractWarning = display.contractWarning {
				Label(contractWarning, systemImage: "exclamationmark.triangle")
					.font(.caption)
					.foregroundStyle(.orange)
			}
		}
		.padding(TestForgeConstants.Spacing.medium)
	}

	@ViewBuilder
	private var firesPane: some View {
		if let fires = viewModel.fires.content {
			let indexedFires = Array(fires.enumerated())
			ScrollView {
				LazyVStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
					ForEach(indexedFires, id: \.element.id) { index, fire in
						NetworkTrackerFireView(fire: fire, index: index)
						Divider()
					}
				}
				.padding(TestForgeConstants.Spacing.medium)
			}
			.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.trackerFires)
		} else if viewModel.fires == .notLoaded {
			NetworkPlaceholderView(phase: .empty(String(localized: "Pick a TRMS ID to see each fire and its payload")))
		} else if let phase = NetworkPlaceholderPhase(state: viewModel.fires) {
			NetworkPlaceholderView(phase: phase)
		}
	}
}
