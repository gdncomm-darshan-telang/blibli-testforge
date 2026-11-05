import SwiftUI

struct NetworkCallRowView: View {
	let call: NetworkCallRowModel

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Text(call.status)
				.font(.caption.monospacedDigit().bold())
				.foregroundStyle(call.isFailure ? Color.red : Color.green)
				.frame(width: TestForgeConstants.Advanced.statusWidth, alignment: .leading)
			Text(call.method)
				.font(.caption.monospaced())
				.foregroundStyle(.secondary)
				.frame(width: TestForgeConstants.Advanced.methodWidth, alignment: .leading)
			VStack(alignment: .leading, spacing: 0) {
				Text(call.path)
					.font(.callout.monospaced())
					.lineLimit(1)
					.truncationMode(.head)
				Text(call.host)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			Spacer()
			Text(call.durationText)
				.font(.caption.monospacedDigit())
				.foregroundStyle(.secondary)
		}
		.help(call.host + call.path)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.fakeDataCallPrefix + call.id)
	}
}
