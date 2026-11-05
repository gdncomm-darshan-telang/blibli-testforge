import SwiftUI

/// D-174: one record button that reads Start recording or End recording; after End, Save or Discard.
struct FlowMapHeaderView: View {
	@ObservedObject var viewModel: FlowMapViewModel

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			recordButton
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(viewModel.headerSummaryText)
					.font(.headline)
					.accessibilityIdentifier(MacroRecorderConstants.Accessibility.summary)
				HStack(spacing: TestForgeConstants.Spacing.small) {
					if viewModel.isReadingScreen || viewModel.state == .starting {
						ProgressView()
							.controlSize(.small)
					}
					Text(subtitle)
						.font(.callout)
						.foregroundStyle(.secondary)
						.lineLimit(1)
						.truncationMode(.middle)
				}
			}
			Spacer()
			if viewModel.phase == .review {
				reviewButtons
			}
		}
		.padding(TestForgeConstants.Spacing.large)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.flowMapHeader)
	}

	private var subtitle: String {
		switch viewModel.phase {
			case .library:
				return String(localized: "Start recording, tap through the app in the Simulator, then End recording to save it as a macro.")
			case .recording:
				return viewModel.lastEventText ?? viewModel.map?.deviceName ?? ""
			case .review:
				return String(localized: "Save it as a macro, or discard it.")
		}
	}

	@ViewBuilder
	private var recordButton: some View {
		switch viewModel.phase {
			case .recording:
				Button(action: viewModel.endRecording) {
					Label("End recording", systemImage: "stop.circle.fill")
				}
				.controlSize(.large)
				.tint(.red)
				.buttonStyle(.borderedProminent)
				.disabled(viewModel.state == .starting)
				.help("Stop recording and save the steps as a macro")
				.accessibilityIdentifier(MacroRecorderConstants.Accessibility.endButton)
				.tutorialAnchor(.scanRecordButton)
			case .library, .review:
				Button(action: viewModel.startRecording) {
					Label("Start recording", systemImage: "record.circle")
				}
				.controlSize(.large)
				.buttonStyle(.borderedProminent)
				.disabled(viewModel.phase == .review)
				.help(viewModel.phase == .review ? "Save or discard the last recording first" : "Record a new macro from what you tap in the Simulator")
				.accessibilityIdentifier(MacroRecorderConstants.Accessibility.startButton)
				.tutorialAnchor(.scanRecordButton)
		}
	}

	private var reviewButtons: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Button(role: .destructive, action: viewModel.requestDiscard) {
				Label("Discard", systemImage: "trash")
			}
			.help("Throw away this recording")
			.accessibilityIdentifier(MacroRecorderConstants.Accessibility.discardButton)
			Button(action: viewModel.beginSaveMacro) {
				Label(viewModel.isSavingMacro ? "Saving…" : "Save as macro…", systemImage: "square.and.arrow.down")
			}
			.buttonStyle(.borderedProminent)
			.disabled(!viewModel.canSaveMacro)
			.help("Turn the recorded steps into a macro that replays without Claude")
			.accessibilityIdentifier(MacroRecorderConstants.Accessibility.saveButton)
		}
	}
}
