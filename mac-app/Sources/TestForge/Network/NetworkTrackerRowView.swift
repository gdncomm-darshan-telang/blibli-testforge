import SwiftUI

struct NetworkTrackerRowView: View {
	let tracker: TrackerRowModel
	let index: Int

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				Image(systemName: verdictSymbol)
					.foregroundStyle(verdictColor)
				Text(tracker.id)
					.font(.callout.monospaced().bold())
				Text(tracker.countText)
					.font(.caption.monospaced())
					.foregroundStyle(.secondary)
					.frame(width: NetworkConsoleConstants.Trackers.countWidth, alignment: .leading)
				Text("\(tracker.eventText) · \(tracker.screenText)")
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
					.truncationMode(.middle)
				Spacer()
			}
			ForEach(tracker.problems, id: \.self) { problem in
				Text(problem)
					.font(.caption)
					.foregroundStyle(.orange)
			}
		}
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.trackerRowPrefix + String(index))
	}

	private var verdictSymbol: String {
		switch tracker.verdict {
			case .fired:
				return "checkmark.circle.fill"
			case .firedWithProblems:
				return "exclamationmark.circle.fill"
			case .rejected:
				return "xmark.octagon.fill"
			case .notFired:
				return "circle.dashed"
		}
	}

	private var verdictColor: Color {
		switch tracker.verdict {
			case .fired:
				return .green
			case .firedWithProblems:
				return .orange
			case .rejected:
				return .red
			case .notFired:
				return .secondary
		}
	}
}
