import SwiftUI

/// Save how every rule is set now under a name; apply one in a click; delete (restarts the app — it can't drop one live).
struct NetworkScenariosBarView<ViewModel: NetworkScenariosPresenting>: View {
	@ObservedObject var viewModel: ViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			controls
			if let failure = viewModel.failure {
				Label(failure.message, systemImage: "exclamationmark.triangle")
					.font(.caption)
					.foregroundStyle(.red)
					.textSelection(.enabled)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.networkScenarioFailure)
			}
		}
		.padding(TestForgeConstants.Spacing.medium)
		.alert("Replace “\(viewModel.pendingReplaceName ?? "")”?", isPresented: isReplaceShown) {
			Button("Replace", role: .destructive, action: viewModel.confirmReplace)
		} message: {
			Text("A scenario with this name exists; it will pin the rules as they are now.")
		}
		.confirmationDialog("Delete “\(viewModel.pendingDelete?.name ?? "")”?", isPresented: isDeleteShown) {
			Button("Delete and restart the app", role: .destructive, action: viewModel.confirmDelete)
		} message: {
			Text("The app can't drop a scenario while it runs, so it is stopped and started again. The rules stay as they are.")
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.scenariosBar)
	}

	private var isBusy: Bool {
		viewModel.runningAction != nil
	}

	private var controls: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: "square.stack.3d.up")
				.foregroundStyle(.secondary)
			TextField("Scenario name, e.g. Flash Sale empty", text: $viewModel.newName)
				.textFieldStyle(.roundedBorder)
				.frame(width: NetworkConsoleConstants.Scenarios.nameFieldWidth)
				.onSubmit(viewModel.save)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.scenarioNameField)
			Button(action: viewModel.save) {
				ActionProgressLabel(
					title: String(localized: "Save current rules"),
					busyTitle: String(localized: "Saving…"),
					isBusy: viewModel.runningAction == .save
				)
			}
			.disabled(isBusy || viewModel.newName.trimmingCharacters(in: .whitespaces).isEmpty)
			.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.saveScenarioButton)
			Spacer()
			if let running = viewModel.runningAction,
				running != .save {
				HStack(spacing: TestForgeConstants.Spacing.small) {
					ProgressView()
						.controlSize(.small)
					Text(running.progressText)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				.accessibilityElement(children: .combine)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.networkScenarioProgress)
			}
			scenarioMenus
				.disabled(isBusy)
		}
	}

	@ViewBuilder
	private var scenarioMenus: some View {
		if let scenarios = viewModel.state.content {
			Menu("Apply scenario") {
				ForEach(scenarios) { scenario in
					Button("\(scenario.name) — \(scenario.summary)") {
						viewModel.apply(scenarioId: scenario.id)
					}
				}
			}
			.frame(maxWidth: NetworkConsoleConstants.Scenarios.menuWidth)
			.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.applyScenarioMenu)
			Menu {
				ForEach(scenarios) { scenario in
					Button(scenario.name, role: .destructive) {
						viewModel.requestDelete(scenario: scenario)
					}
				}
			} label: {
				Image(systemName: "trash")
			}
			.menuIndicator(.hidden)
			.fixedSize()
			.help("Delete a scenario")
			.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.deleteScenarioMenu)
		} else if case .empty(let hint) = viewModel.state {
			Text(hint)
				.foregroundStyle(.secondary)
		}
	}

	private var isReplaceShown: Binding<Bool> {
		Binding {
			viewModel.pendingReplaceName != nil
		} set: { isShown in
			if !isShown {
				viewModel.pendingReplaceName = nil
			}
		}
	}

	private var isDeleteShown: Binding<Bool> {
		Binding {
			viewModel.pendingDelete != nil
		} set: { isShown in
			if !isShown {
				viewModel.pendingDelete = nil
			}
		}
	}
}
