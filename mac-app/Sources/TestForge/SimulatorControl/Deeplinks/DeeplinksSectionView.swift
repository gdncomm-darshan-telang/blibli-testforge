import SwiftUI

/// Simulator › Deeplinks (D-157): pick a screen or type a link, see which route catches it, open it without a relaunch.
struct DeeplinksSectionView: View {
	@ObservedObject var viewModel: DeeplinksSectionViewModel

	var body: some View {
		SimulatorCardView(card: Self.card) {
			catalogContent
		}
		.tutorialAnchor(.simulatorDeeplinks)
		.onAppear {
			viewModel.load()
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinks)
	}

	@ViewBuilder
	private var catalogContent: some View {
		switch viewModel.catalogState {
			case .loading:
				LoadingStateView(text: "Reading the app's routes…")
			case .failed(let message):
				Label(message, systemImage: "exclamationmark.triangle")
					.foregroundStyle(.orange)
			case .loaded:
				builder
		}
	}

	@ViewBuilder
	private var builder: some View {
		DeeplinkRoutePickerView(searchText: $viewModel.searchText, content: viewModel.routeSearchContent, actions: routeSearchActions)
		if !viewModel.paramFields.isEmpty {
			DeeplinkParamFieldsView(fields: viewModel.paramFields, values: viewModel.paramValues) { name, value in
				viewModel.setParam(name: name, value: value)
			}
		}
		DeeplinkLinkRowView(link: $viewModel.link, availability: availability, actions: linkActions)
		DeeplinkQueryFieldsView(content: viewModel.queryFieldsContent, actions: queryActions)
		statusLines
		if viewModel.hasEntries {
			DeeplinkEntryListView(groups: entryGroups, isOpenEnabled: !viewModel.isLocked, actions: entryActions)
		}
	}

	@ViewBuilder
	private var statusLines: some View {
		if let problem = viewModel.problemText {
			Label(problem, systemImage: "exclamationmark.triangle")
				.font(.caption)
				.foregroundStyle(.orange)
		} else if let matchText = viewModel.matchText {
			Label(matchText, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		switch viewModel.openState {
			case .idle:
				EmptyView()
			case .opening:
				ProgressView()
					.controlSize(.small)
			case .opened(let message):
				Label(message, systemImage: "checkmark.circle.fill")
					.font(.caption)
					.foregroundStyle(.green)
			case .failed(let message):
				Label(message, systemImage: "xmark.octagon")
					.font(.caption)
					.foregroundStyle(.red)
		}
	}

	private var queryActions: DeeplinkQueryActions {
		DeeplinkQueryActions(add: viewModel.addQueryItem, change: viewModel.changeQueryItem, remove: { id in viewModel.removeQueryItem(id: id) })
	}

	private var routeSearchActions: DeeplinkRouteSearchActions {
		DeeplinkRouteSearchActions(select: { id in viewModel.selectRoute(id: id) }, clear: viewModel.clearRoute)
	}

	private var availability: DeeplinkLinkAvailability {
		DeeplinkLinkAvailability(canOpen: viewModel.canOpen, canSave: viewModel.canSave)
	}

	private var linkActions: DeeplinkLinkActions {
		DeeplinkLinkActions(open: { viewModel.open() }, save: viewModel.saveCurrent)
	}

	private var entryGroups: DeeplinkEntryGroups {
		DeeplinkEntryGroups(saved: viewModel.savedRows, recent: viewModel.recentRows)
	}

	private var entryActions: DeeplinkEntryActions {
		DeeplinkEntryActions(open: { url in viewModel.open(url: url) }, remove: viewModel.removeSaved)
	}
}

private extension DeeplinksSectionView {
	static let card = SimulatorCard(
		name: "Deeplinks",
		title: "Deeplinks",
		systemImage: "link",
		tint: .blue,
		footer: "Find a screen or type a link. Opens in the running app over the current screen, no relaunch. Screens: the app's DeeplinkList.txt."
	)
}
