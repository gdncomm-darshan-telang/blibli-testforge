import SwiftUI

struct RunQueueRowView: View {
	let row: RunQueueRowModel
	let actionState: RunQueueRowActionState
	let onAction: (RunQueueTaskAction) -> Void

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			statusIcon
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(row.title)
					.lineLimit(2)
				Text(row.detail)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(2)
					.textSelection(.enabled)
				if let failure = actionState.failure {
					Label(failure, systemImage: "exclamationmark.triangle")
						.font(.caption)
						.foregroundStyle(.orange)
						.textSelection(.enabled)
						.accessibilityIdentifier(TestForgeConstants.Accessibility.runQueueRowFailurePrefix + row.id)
				}
			}
			Spacer()
			actions
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.runQueueRowPrefix + row.id)
	}

	@ViewBuilder
	private var statusIcon: some View {
		if row.isRunning {
			ProgressView()
				.controlSize(.small)
		} else {
			Image(systemName: row.statusSymbol)
				.foregroundStyle(color)
				.accessibilityHidden(true)
		}
	}

	@ViewBuilder
	private var actions: some View {
		if let pendingAction = actionState.pendingAction {
			HStack(spacing: TestForgeConstants.Spacing.small) {
				ProgressView()
					.controlSize(.small)
				Text(pendingAction.busyTitle)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.accessibilityElement(children: .combine)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.runQueueRowPendingPrefix + row.id)
		} else {
			actionButtons
		}
	}

	private var actionButtons: some View {
		HStack(spacing: TestForgeConstants.Spacing.small) {
			if row.canMoveUp || row.canMoveDown {
				Button("Move up", systemImage: "arrow.up") {
					onAction(.moveUp)
				}
				.disabled(!row.canMoveUp)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.runQueueMoveUpPrefix + row.id)
				Button("Move down", systemImage: "arrow.down") {
					onAction(.moveDown)
				}
				.disabled(!row.canMoveDown)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.runQueueMoveDownPrefix + row.id)
			}
			if row.canCancel {
				Button("Cancel", systemImage: "xmark") {
					onAction(.cancel)
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.runQueueCancelPrefix + row.id)
			}
			if row.canRetry {
				Button("Retry", systemImage: "arrow.counterclockwise") {
					onAction(.retry)
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.runQueueRetryPrefix + row.id)
			}
		}
		.labelStyle(.iconOnly)
		.buttonStyle(.borderless)
	}

	private var color: Color {
		switch row.tone {
			case .passed:
				return .green
			case .failed:
				return .red
			case .neutral:
				return .orange
			case .notRun:
				return .secondary
		}
	}
}
