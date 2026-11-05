import SwiftUI

/// Traffic tab: the call list on the left (search on the server, Mocked filter here), the selected call on the right.
struct NetworkTrafficSectionView<ViewModel: NetworkTrafficPresenting>: View {
	@ObservedObject var viewModel: ViewModel

	var body: some View {
		HStack(spacing: 0) {
			VStack(spacing: 0) {
				filterBar
				Divider()
				callList
			}
			.frame(width: NetworkConsoleConstants.Traffic.listWidth)
			Divider()
			detailPane
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.traffic)
		.tutorialAnchor(.networkTraffic)
	}

	@ViewBuilder
	private var filterBar: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			TextField("Filter by URL", text: $viewModel.searchText)
				.textFieldStyle(.roundedBorder)
				.frame(maxWidth: NetworkConsoleConstants.Traffic.searchFieldWidth)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.searchField)
			Toggle("Mocked only", isOn: $viewModel.isMockedOnly)
				.toggleStyle(.checkbox)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.mockedOnlyToggle)
			Spacer()
		}
		.padding(TestForgeConstants.Spacing.medium)
	}

	@ViewBuilder
	private var callList: some View {
		if let calls = viewModel.state.content {
			let indexedCalls = Array(calls.enumerated())
			List(selection: $viewModel.selectedCallId) {
				ForEach(indexedCalls, id: \.element.id) { index, call in
					NetworkTrafficRowView(call: call, index: index)
						.tag(call.id)
				}
			}
			.listStyle(.inset)
		} else if let phase = NetworkPlaceholderPhase(state: viewModel.state) {
			NetworkPlaceholderView(phase: phase)
		}
	}

	@ViewBuilder
	private var detailPane: some View {
		if let detail = viewModel.detail.content {
			let actions = NetworkCallDetailActions(
				mockCall: viewModel.mockSelectedCall,
				copyCurl: viewModel.copyCurl,
				replay: viewModel.replaySelectedCall,
				hold: viewModel.holdSelectedCall
			)
			NetworkCallDetailView(detail: detail, actions: actions, activity: viewModel.callActivity)
		} else if viewModel.detail == .notLoaded {
			NetworkPlaceholderView(phase: .empty(String(localized: "Pick a call to see its response")))
		} else if let phase = NetworkPlaceholderPhase(state: viewModel.detail) {
			NetworkPlaceholderView(phase: phase)
		}
	}
}
