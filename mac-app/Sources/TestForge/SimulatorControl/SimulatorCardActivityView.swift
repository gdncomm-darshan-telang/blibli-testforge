import SwiftUI

/// D-213: the progress or result line inside the card whose button started the work.
struct SimulatorCardActivityView: View {
	let activity: SimulatorCardActivity?
	let card: SimulatorCardKind

	var body: some View {
		switch activity {
			case .running(let title):
				HStack(spacing: TestForgeConstants.Spacing.small) {
					ProgressView()
						.controlSize(.small)
					Text("\(title)…")
				}
				.font(.callout)
				.accessibilityElement(children: .combine)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorCardProgressPrefix + card.rawValue)
			case .finished(let result):
				Label {
					Text("\(result.title): \(result.message)")
						.textSelection(.enabled)
						.lineLimit(TestForgeConstants.SimulatorControl.resultLineLimit)
				} icon: {
					Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
						.foregroundStyle(result.isSuccess ? Color.green : Color.orange)
				}
				.font(.callout)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorCardResultPrefix + card.rawValue)
			case nil:
				EmptyView()
		}
	}
}
