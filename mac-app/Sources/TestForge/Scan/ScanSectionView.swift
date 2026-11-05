import SwiftUI

/// Scan mode: what the harness sees right now, the name-and-mark bar, and the screens recorded so far.
struct ScanSectionView: View {
	@ObservedObject var viewModel: ScanSectionViewModel

	var body: some View {
		stateContent
			.alert(actionFailedTitle, isPresented: isActionMessagePresented) {
				Button("OK") {
					viewModel.dismissMessage()
				}
			} message: {
				Text(viewModel.actionMessage ?? "")
			}
			.accessibilityElement(children: .contain)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.scan)
	}

	@ViewBuilder
	private var stateContent: some View {
		switch viewModel.state {
			case .idle(let lastScan):
				let actions = ScanIdleActions(
					start: { viewModel.startScan() },
					reveal: { viewModel.revealLastScan() },
					showSimulator: { viewModel.showSimulator() }
				)
				ScanIdleView(lastScan: lastScan, isStarting: viewModel.isRunning(.start), actions: actions)
			case .active(let live):
				liveContent(live: live)
		}
	}

	private func liveContent(live: ScanLiveModel) -> some View {
		VStack(spacing: 0) {
			let headerActions = ScanHeaderActions(stop: { viewModel.stopScan() }, showSimulator: { viewModel.showSimulator() })
			ScanHeaderView(live: live, actions: headerActions)
			Divider()
			HStack(spacing: 0) {
				VStack(spacing: 0) {
					ScanCurrentScreenView(current: live.current)
					Divider()
					let markActions = ScanMarkActions(mark: { viewModel.markScreen() }, skip: { viewModel.skipScreen() })
					ScanMarkBarView(screenName: $viewModel.screenName, model: viewModel.markBar, actions: markActions)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				Divider()
				ScanScreenListView(screens: live.screens)
					.frame(width: TestForgeConstants.Scan.screenListWidth)
			}
		}
	}

	private var actionFailedTitle: Text {
		Text("That didn't work")
	}

	private var isActionMessagePresented: Binding<Bool> {
		Binding {
			viewModel.actionMessage != nil
		} set: { isPresented in
			if !isPresented {
				viewModel.dismissMessage()
			}
		}
	}
}
