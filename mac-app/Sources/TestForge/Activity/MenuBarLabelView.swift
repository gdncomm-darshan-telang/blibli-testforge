import SwiftUI

struct MenuBarLabelView: View {
	@ObservedObject var viewModel: RunActivityViewModel

	var body: some View {
		Image(systemName: symbolName)
			.accessibilityLabel(accessibilityText)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.menuBarLabel)
	}

	private var symbolName: String {
		if viewModel.stopError != nil {
			return "exclamationmark.triangle.fill"
		}
		if viewModel.pendingControl != nil {
			return "hourglass"
		}
		switch viewModel.state {
			case .idle:
				return "checkmark.seal"
			case .running:
				return "play.circle.fill"
		}
	}

	private var accessibilityText: Text {
		if viewModel.stopError != nil {
			return Text("TestForge, the last Stop or Continue failed")
		}
		switch viewModel.state {
			case .idle:
				return Text("TestForge")
			case .running:
				return Text("TestForge, a run is in progress")
		}
	}
}
