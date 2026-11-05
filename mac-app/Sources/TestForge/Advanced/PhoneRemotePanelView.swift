import SwiftUI

/// Phone remote: build one driver command, send it to the simulator, read the answer.
struct PhoneRemotePanelView: View {
	@ObservedObject var viewModel: PhoneRemoteViewModel

	var body: some View {
		HStack(spacing: 0) {
			DriverCommandFormView(viewModel: viewModel)
				.frame(width: TestForgeConstants.Advanced.formWidth)
			Divider()
			VStack(spacing: 0) {
				DriverResultView(result: viewModel.selectedResult)
				Divider()
				historyList
					.frame(height: TestForgeConstants.Advanced.historyHeight)
			}
		}
		.onAppear {
			viewModel.refreshHost()
		}
		.confirmationDialog("Relaunch the app?", isPresented: $viewModel.isRelaunchConfirmationShown) {
			Button("Relaunch", role: .destructive) {
				viewModel.confirmRelaunch()
			}
		} message: {
			Text("Whatever screen is open on the simulator closes.")
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.phoneRemote)
	}

	private var historyList: some View {
		List(viewModel.history, selection: $viewModel.selectedResultId) { result in
			PhoneRemoteHistoryRowView(result: result)
				.tag(result.id)
		}
		.overlay {
			if viewModel.history.isEmpty {
				Text("Commands sent this session appear here.")
					.font(.callout)
					.foregroundStyle(.secondary)
			}
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.phoneRemoteHistory)
		.tutorialAnchor(.phoneRemoteHistory)
	}
}
