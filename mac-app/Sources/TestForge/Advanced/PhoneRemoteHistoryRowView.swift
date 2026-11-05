import SwiftUI

struct PhoneRemoteHistoryRowView: View {
	let result: PhoneRemoteResult

	var body: some View {
		HStack {
			PhoneRemoteOutcomeLabelView(outcome: result.outcome, title: result.title)
				.lineLimit(1)
			Spacer()
			Text(result.sentAt, style: .time)
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.phoneRemoteHistoryRowPrefix + result.id.uuidString)
	}
}
