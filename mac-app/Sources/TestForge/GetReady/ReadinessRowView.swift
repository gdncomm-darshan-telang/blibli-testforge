import SwiftUI

struct ReadinessRowView: View {
	let row: ReadinessRowModel
	let fixState: ReadinessFixState
	let onFix: () -> Void

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			statusIcon
				.frame(width: TestForgeConstants.GetReady.rowIconSize)
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(row.title)
					.font(.body.weight(.medium))
				if !row.detail.isEmpty {
					Text(row.detail)
						.font(.callout)
						.foregroundStyle(.secondary)
						.textSelection(.enabled)
				}
				if let outcome = fixState.outcome {
					Label(outcome.message, systemImage: outcome.isSuccess ? "checkmark.circle" : "exclamationmark.triangle")
						.font(.callout)
						.foregroundStyle(outcome.isSuccess ? Color.green : Color.orange)
						.textSelection(.enabled)
						.accessibilityIdentifier(TestForgeConstants.Accessibility.readinessFixOutcomePrefix + row.id)
				}
			}
			Spacer(minLength: TestForgeConstants.Spacing.medium)
			if let fixAction = row.fixAction {
				Button {
					onFix()
				} label: {
					ActionProgressLabel(title: String(localized: fixAction.title), busyTitle: fixState.busyTitle ?? "", isBusy: isFixing)
				}
				.disabled(isFixing)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.fixButtonPrefix + row.id)
			}
		}
		.padding(.vertical, TestForgeConstants.Spacing.medium)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.readinessRowPrefix + row.id)
	}

	private var isFixing: Bool {
		fixState.busyTitle != nil
	}

	@ViewBuilder
	private var statusIcon: some View {
		switch row.status {
			case .waiting:
				Image(systemName: "circle.dotted")
					.foregroundStyle(.tertiary)
			case .working:
				ProgressView()
					.controlSize(.small)
			case .passed:
				Image(systemName: "checkmark.circle.fill")
					.foregroundStyle(.green)
			case .warning:
				Image(systemName: "exclamationmark.triangle.fill")
					.foregroundStyle(.orange)
			case .blocking:
				Image(systemName: "xmark.octagon.fill")
					.foregroundStyle(.red)
		}
	}
}
