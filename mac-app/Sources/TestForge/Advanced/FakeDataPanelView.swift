import SwiftUI

/// Fake data: the master switch, one row per NetworkLens rule, the chosen answer, and the app's recent calls.
struct FakeDataPanelView: View {
	@ObservedObject var viewModel: FakeDataViewModel

	var body: some View {
		VStack(spacing: 0) {
			statusBar
			Divider()
			HStack(spacing: 0) {
				ruleList
					.frame(width: TestForgeConstants.Advanced.ruleListWidth)
				Divider()
				VStack(spacing: 0) {
					MockVariantDetailView(detail: viewModel.variantDetail)
					Divider()
					NetworkCallListView(calls: viewModel.content.calls, selection: $viewModel.selectedCallId, callBody: viewModel.callBody)
				}
			}
		}
		.alert("That didn't work", isPresented: isMessagePresented) {
			Button("OK") {
				viewModel.dismissMessage()
			}
		} message: {
			Text(viewModel.actionMessage ?? "")
		}
		.confirmationDialog("Turn NetworkLens on?", isPresented: $viewModel.isNetworkLensConfirmationShown) {
			Button("Turn on and relaunch the app") {
				viewModel.enableNetworkLens()
			}
		} message: {
			Text("The app on the simulator relaunches, so whatever screen is open now closes.")
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.fakeData)
	}

	private var statusBar: some View {
		let status = viewModel.content.status
		return HStack(spacing: TestForgeConstants.Spacing.medium) {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(status.title)
					.font(.headline)
				Text(status.detail)
					.font(.callout)
					.foregroundStyle(.secondary)
			}
			.accessibilityElement(children: .combine)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.fakeDataStatus)
			Spacer()
			Button {
				viewModel.requestNetworkLens()
			} label: {
				ActionProgressLabel(
					title: String(localized: "Turn NetworkLens on…"),
					busyTitle: String(localized: "Relaunching…"),
					isBusy: viewModel.isEnablingNetworkLens
				)
			}
			.disabled(viewModel.isSessionBusy)
			.help("Relaunches the app with NetworkLens on, which network mocks and the call list need")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.fakeDataNetworkLensButton)
			if let pendingMocking = viewModel.pendingMocking {
				HStack(spacing: TestForgeConstants.Spacing.small) {
					ProgressView()
						.controlSize(.small)
					Text(pendingMocking ? "Turning on…" : "Turning off…")
						.font(.callout)
						.foregroundStyle(.secondary)
				}
				.accessibilityElement(children: .combine)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.fakeDataMasterSwitchProgress)
			}
			Toggle("Network mocks", isOn: masterSwitch)
				.toggleStyle(.switch)
				.disabled(viewModel.isSessionBusy)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.fakeDataMasterSwitch)
				.tutorialAnchor(.fakeDataMasterSwitch)
		}
		.padding(TestForgeConstants.Spacing.medium)
	}

	private var ruleList: some View {
		List(selection: $viewModel.selectedRuleId) {
			Section("Rules") {
				ForEach(viewModel.content.rules) { rule in
					MockRuleRowView(rule: rule, isBusy: viewModel.busyRuleIds.contains(rule.id), actions: ruleActions)
						.tag(rule.id)
				}
			}
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.fakeDataRuleList)
		.tutorialAnchor(.fakeDataRuleList)
	}

	private var ruleActions: MockRuleActions {
		MockRuleActions(
			setEnabled: { id, isEnabled in viewModel.setRule(id: id, isEnabled: isEnabled) },
			activate: { ruleId, variantId in viewModel.activate(ruleId: ruleId, variantId: variantId) }
		)
	}

	private var masterSwitch: Binding<Bool> {
		Binding {
			viewModel.isMockingSwitchOn
		} set: { isEnabled in
			viewModel.setMocking(isEnabled: isEnabled)
		}
	}

	private var isMessagePresented: Binding<Bool> {
		Binding {
			viewModel.actionMessage != nil
		} set: { isPresented in
			if !isPresented {
				viewModel.dismissMessage()
			}
		}
	}
}
