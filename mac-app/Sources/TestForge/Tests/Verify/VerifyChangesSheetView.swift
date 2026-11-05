import SwiftUI

/// Tests › Verify my changes (D-196): compare the branch with its base, see which recorded cases it touches, replay them.
struct VerifyChangesSheetView: View {
	@ObservedObject var viewModel: VerifyChangesViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			Text("Verify my changes")
				.font(.title3.weight(.semibold))
			content
			buttons
		}
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(width: TestForgeConstants.GetReady.prerequisitesWidth)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.verifySheet)
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.state {
			case .hidden, .choosing:
				form
			case .loading:
				LoadingStateView(text: "Comparing your code with \(viewModel.base)…")
			case .failed(let message):
				Label(message, systemImage: "exclamationmark.triangle")
					.foregroundStyle(.red)
					.textSelection(.enabled)
			case .loaded(let plan):
				result(plan)
		}
	}

	private var form: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Text("Finds the loaded cases whose recordings cover the app code your branch changes, to replay them without Claude.")
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
			TextField("Compare with branch", text: $viewModel.base)
				.textFieldStyle(.roundedBorder)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.verifyBase)
			Toggle("Include uncommitted edits", isOn: $viewModel.isIncludingLocalEdits)
				.toggleStyle(.checkbox)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.verifyIncludeLocal)
			Text("The QA build must contain these changes — build for QA first if it doesn't.")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}

	private func result(_ plan: VerifyPlan) -> some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Text("\(plan.range) · \(plan.changedAppFiles.count) app file(s) changed")
				.font(.callout)
				.foregroundStyle(.secondary)
			if plan.isSharedChange {
				Label("Dependencies changed — every recorded case is picked.", systemImage: "shippingbox")
			}
			if plan.cases.isEmpty {
				Text("No loaded case's recording covers these changes.")
			} else {
				List(plan.cases) { entry in
					VerifyCaseRowView(entry: entry)
				}
				.frame(height: TestForgeConstants.Tests.verifyListHeight)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.verifyList)
			}
			if !plan.uncoveredFiles.isEmpty {
				DisclosureGroup("\(plan.uncoveredFiles.count) changed file(s) no recording covers") {
					Text(plan.uncoveredFiles.joined(separator: "\n"))
						.font(.caption.monospaced())
						.textSelection(.enabled)
						.frame(maxWidth: .infinity, alignment: .leading)
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.verifyUncovered)
			}
		}
	}

	private var buttons: some View {
		HStack {
			if case .loaded = viewModel.state {
				Button("Change comparison", action: viewModel.backToForm)
			}
			Spacer()
			Button("Cancel", role: .cancel, action: viewModel.dismiss)
				.keyboardShortcut(.cancelAction)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.verifyCancel)
			if case .loaded = viewModel.state {
				Button("Replay \(viewModel.pickedCaseIds.count) case(s)…", action: viewModel.replayPicked)
					.keyboardShortcut(.defaultAction)
					.disabled(viewModel.pickedCaseIds.isEmpty)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.verifyReplay)
			} else {
				Button("Check", action: viewModel.check)
					.keyboardShortcut(.defaultAction)
					.disabled(viewModel.state == .loading)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.verifyCheck)
			}
		}
	}
}
