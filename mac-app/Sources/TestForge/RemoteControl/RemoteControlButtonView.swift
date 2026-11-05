import SwiftUI

/// Claude section header: Remote Control's state at a glance; opens its panel.
struct RemoteControlButtonView<ViewModel: RemoteControlPresenting>: View {
	@ObservedObject var viewModel: ViewModel
	@State private var isPanelShown = false

	var body: some View {
		Button {
			isPanelShown.toggle()
		} label: {
			Label {
				Text("Remote Control")
			} icon: {
				Image(systemName: "iphone.radiowaves.left.and.right")
					.foregroundStyle(dotColor)
			}
		}
		.help("Run QA on this Mac from the Claude app or claude.ai/code")
		.popover(isPresented: $isPanelShown, arrowEdge: .bottom) {
			RemoteControlPanelView(viewModel: viewModel)
		}
		.accessibilityIdentifier(RemoteControlConstants.Accessibility.button)
		.tutorialAnchor(.remoteControlButton)
	}

	private var dotColor: Color {
		switch viewModel.display.status {
			case .off:
				return .secondary
			case .starting:
				return .orange
			case .connected:
				return .green
			case .problem:
				return .red
		}
	}
}
