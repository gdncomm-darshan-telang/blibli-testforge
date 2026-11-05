import SwiftUI

struct UsageSegmentView: View {
	let segment: UsageSegment

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.small) {
			Text("\(segment.label):")
				.bold()
			Text(segment.value)
		}
		.foregroundStyle(color)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(UsageBarConstants.Accessibility.segmentPrefix + segment.id)
	}

	private var color: Color {
		switch segment.level {
			case .normal:
				return .purple
			case .ahead:
				return .orange
			case .critical:
				return .red
		}
	}
}
