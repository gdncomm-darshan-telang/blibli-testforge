import SwiftUI

/// Top strip: live vs next launch at a glance — explains "why didn't the screen change?" before anyone asks.
struct NetworkHealthStripView<ViewModel: NetworkHealthPresenting>: View {
	@ObservedObject var viewModel: ViewModel

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			if let model = viewModel.state.content {
				Image(systemName: model.symbolName)
					.foregroundStyle(tint(for: model.tone))
				VStack(alignment: .leading, spacing: 0) {
					Text(model.title)
						.font(.headline)
					Text(model.detail)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				Spacer()
				Text(model.ruleSummary)
					.font(.callout)
					.foregroundStyle(.secondary)
				if viewModel.isSwitching {
					ProgressView()
						.controlSize(.small)
				}
				Toggle("Mocks", isOn: mockingBinding(isOn: model.isMockingEnabled))
					.toggleStyle(.switch)
					.disabled(viewModel.isSwitching)
					.help("The master switch: off, every call goes to the real backend")
					.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.mockingToggle)
			} else if case .failed(let message) = viewModel.state {
				Image(systemName: "bolt.horizontal.circle")
					.foregroundStyle(.orange)
				Text(message)
					.foregroundStyle(.secondary)
				Spacer()
			} else {
				ProgressView()
					.controlSize(.small)
				Text("Checking NetworkLens…")
					.foregroundStyle(.secondary)
				Spacer()
			}
		}
		.padding(TestForgeConstants.Spacing.medium)
		.background(.quaternary.opacity(NetworkConsoleConstants.Surface.stripOpacity))
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.healthStrip)
		.tutorialAnchor(.networkHealthStrip)
	}

	private func tint(for tone: NetworkHealthTone) -> Color {
		switch tone {
			case .good:
				return .green
			case .warning:
				return .orange
			case .off:
				return .secondary
		}
	}

	private func mockingBinding(isOn: Bool) -> Binding<Bool> {
		Binding {
			isOn
		} set: { isEnabled in
			viewModel.setMocking(isEnabled: isEnabled)
		}
	}
}
