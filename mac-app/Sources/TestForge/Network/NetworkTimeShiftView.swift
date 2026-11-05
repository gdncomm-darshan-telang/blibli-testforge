import SwiftUI

/// "This timestamp lands N seconds from now" — the others move with it, so a schedule keeps its shape.
struct NetworkTimeShiftView: View {
	@ObservedObject var viewModel: NetworkVariantEditorViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				Text("Time-shift")
					.font(.headline)
				Spacer()
				Button("Find timestamps", systemImage: "clock.arrow.circlepath", action: viewModel.loadTimestamps)
			}
			content
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.timeShift)
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.timestamps {
			case .notLoaded:
				Text("Move every time in this body so a chosen one starts or ends a few seconds from now.")
					.font(.caption)
					.foregroundStyle(.secondary)
			case .loading:
				ProgressView()
					.controlSize(.small)
			case .empty(let hint), .failed(let hint):
				Text(hint)
					.font(.caption)
					.foregroundStyle(.secondary)
			case .loaded(let timestamps):
				List(timestamps, id: \.path, selection: $viewModel.selectedAnchorPath) { timestamp in
					HStack {
						Text(timestamp.path)
							.font(.caption.monospaced())
						Spacer()
						Text("now \(timestamp.inSeconds) s")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					.tag(timestamp.path)
				}
				.frame(height: NetworkConsoleConstants.Editor.timeShiftListHeight)
				HStack(spacing: TestForgeConstants.Spacing.medium) {
					Text("Lands in")
					TextField("Seconds", text: $viewModel.shiftSecondsText)
						.textFieldStyle(.roundedBorder)
						.frame(width: NetworkConsoleConstants.Editor.numberFieldWidth)
						.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.timeShiftSecondsField)
					Text("s from now")
					Spacer()
					Button("Shift and save", systemImage: "clock.badge.checkmark", action: viewModel.timeShift)
						.disabled(viewModel.selectedAnchorPath == nil)
						.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.timeShiftButton)
				}
		}
	}
}
