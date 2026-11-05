import SwiftUI

/// One recording: what it checks, where its file lives, and every step in order.
struct MacroDetailView: View {
	let detail: MacroDetailState
	let replay: MacroReplayFeedback
	let onReplay: () -> Void

	var body: some View {
		stateContent
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.accessibilityElement(children: .contain)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.recordedStepsDetail)
			.tutorialAnchor(.recordedStepsDetail)
	}

	@ViewBuilder
	private var stateContent: some View {
		switch detail {
			case .notSelected:
				EmptyStateView(content: EmptyStateContent(
					title: "Pick a recording",
					systemImage: "list.bullet.rectangle",
					message: "Select a recording to see its steps and replay it on the simulator."
				))
			case .loading:
				ProgressView()
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .loaded(let model):
				loadedContent(model: model)
			case .failed(let message):
				EmptyStateView(content: EmptyStateContent(
					title: "Couldn't read this recording",
					systemImage: "exclamationmark.triangle",
					message: "\(message)"
				))
		}
	}

	private func loadedContent(model: MacroDetailModel) -> some View {
		Form {
			Section {
				HStack(alignment: .firstTextBaseline) {
					Text(model.name)
						.font(.headline)
						.textSelection(.enabled)
					Spacer()
					Button(action: onReplay) {
						if replay.isQueuing {
							ActionProgressLabel(title: String(localized: "Replay"), busyTitle: String(localized: "Queuing…"), isBusy: true)
						} else {
							Label("Replay", systemImage: "play.fill")
						}
					}
					.disabled(replay.isQueuing)
					.help("Queue this recording on the simulator")
					.accessibilityIdentifier(TestForgeConstants.Accessibility.recordedStepsReplayButton)
				}
				if let replayNotice = replay.notice {
					Text(replayNotice)
						.font(.callout)
						.foregroundStyle(.green)
				}
				if !model.description.isEmpty {
					Text(model.description)
						.font(.callout)
						.foregroundStyle(.secondary)
						.textSelection(.enabled)
				}
				LabeledContent("File", value: model.path)
				LabeledContent("Id", value: model.macroId)
			}
			Section("Steps") {
				ForEach(model.steps) { step in
					MacroStepRowView(step: step)
				}
			}
		}
		.formStyle(.grouped)
	}
}
