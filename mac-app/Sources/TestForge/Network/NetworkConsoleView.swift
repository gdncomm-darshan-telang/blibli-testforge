import SwiftUI

/// Network section (D-128): health strip, leftover-mock banner, then the selected tab. Refreshes only while shown.
struct NetworkConsoleView: View {
	@ObservedObject var viewModel: NetworkConsoleViewModel

	var body: some View {
		VStack(spacing: 0) {
			NetworkHealthStripView(viewModel: viewModel.health)
			NetworkGuardrailsBannerView(viewModel: viewModel.guardrails)
			Divider()
			tabBar
			Divider()
			switch viewModel.selectedTab {
				case .traffic:
					NetworkTrafficSectionView(viewModel: viewModel.traffic)
				case .rules:
					NetworkScenariosBarView(viewModel: viewModel.scenarios)
					Divider()
					NetworkRulesSectionView(viewModel: viewModel.rules)
				case .breakpoints:
					NetworkBreakpointsSectionView(viewModel: viewModel.breakpoints)
				case .trackers:
					NetworkTrackersSectionView(viewModel: viewModel.trackers)
			}
		}
		.onAppear(perform: viewModel.start)
		.onDisappear(perform: viewModel.stop)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.page)
	}

	@ViewBuilder
	private var tabBar: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Picker("View", selection: $viewModel.selectedTab) {
				ForEach(NetworkConsoleTab.allCases) { tab in
					Text(tab.title).tag(tab)
				}
			}
			.pickerStyle(.segmented)
			.labelsHidden()
			.fixedSize()
			.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.tabPicker)
			.tutorialAnchor(.networkTabs)
			if let message = viewModel.message {
				Text(message)
					.font(.callout)
					.foregroundStyle(.secondary)
					.lineLimit(2)
					.textSelection(.enabled)
				Button("Dismiss", systemImage: "xmark.circle.fill", action: viewModel.dismissMessage)
					.labelStyle(.iconOnly)
					.buttonStyle(.borderless)
			}
			Spacer()
		}
		.padding(TestForgeConstants.Spacing.medium)
	}
}
