import SwiftUI

struct LiveStepsActions {
	/// D-213: Stop was clicked and the run hasn't stopped yet.
	let isStopping: Bool

	let stop: () -> Void
	let showClaudeSession: (String) -> Void
}

/// Board C4: the newest run's steps in plain words, updating as the server narrates them.
struct LiveStepsInspectorView: View {
	let state: LiveStepsState
	let actions: LiveStepsActions

	var body: some View {
		stateContent
			.accessibilityElement(children: .contain)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsInspector)
			.tutorialAnchor(.testsInspector)
	}

	private static let idleContent = EmptyStateContent(
		title: "No run yet",
		systemImage: "waveform.path.ecg",
		message: "Steps appear here while a test runs."
	)

	@ViewBuilder
	private var stateContent: some View {
		switch state {
			case .idle:
				EmptyStateView(content: Self.idleContent)
			case .showing(let run):
				runContent(run: run)
		}
	}

	private func runContent(run: LiveRunModel) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			runHeader(run: run)
			Divider()
			if let prep = run.prep {
				LivePrepSectionView(prep: prep)
				Divider()
			}
			ScrollViewReader { proxy in
				List(run.steps) { step in
					LiveStepRowView(step: step)
						.id(step.id)
				}
				.listStyle(.plain)
				.onChange(of: run.steps.count) {
					guard let lastStepId = run.steps.last?.id else {
						return
					}
					proxy.scrollTo(lastStepId, anchor: .bottom)
				}
			}
		}
	}

	private func runHeader(run: LiveRunModel) -> some View {
		HStack(alignment: .top, spacing: TestForgeConstants.Spacing.medium) {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(run.title)
					.font(.headline)
					.lineLimit(2)
				Text(run.statusText)
					.font(.caption)
					.foregroundStyle(.secondary)
				if let modelText = run.modelText {
					Label(modelText, systemImage: "cpu")
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(2)
						.help("The model this Claude run is on. Auto starts on the cheapest model the case looks simple enough for and moves up if it gets stuck.")
				}
			}
			Spacer()
			if let sessionId = run.sessionId {
				Button("Claude session", systemImage: "sparkles") {
					actions.showClaudeSession(sessionId)
				}
				.help("Everything Claude did and said in this run, with its approvals and questions — and a box to tell it what to do")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testsShowClaudeSessionButton)
			}
			if run.isRunning {
				Button(role: .destructive) {
					actions.stop()
				} label: {
					BusyActionLabel(title: String(localized: "Stop"), systemImage: "stop.fill", busyTitle: stopBusyTitle)
				}
				.disabled(actions.isStopping)
				.help("Stop this run (⌘.)")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testsStopButton)
			}
		}
		.padding(TestForgeConstants.Spacing.medium)
	}

	private var stopBusyTitle: String? {
		actions.isStopping ? String(localized: "Stopping…") : nil
	}
}
