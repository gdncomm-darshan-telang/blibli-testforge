import SwiftUI

struct NetworkTrafficRowView: View {
	let call: TrafficCallRowModel
	let index: Int

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Text(call.method)
				.font(.caption.monospaced().bold())
				.foregroundStyle(.secondary)
				.frame(width: NetworkConsoleConstants.Traffic.methodWidth, alignment: .leading)
			Text(call.statusText)
				.font(.caption.monospaced())
				.foregroundStyle(call.isFailure ? .red : .primary)
				.frame(width: NetworkConsoleConstants.Traffic.statusWidth, alignment: .leading)
			Text(call.path)
				.font(.callout.monospaced())
				.lineLimit(1)
				.truncationMode(.middle)
				.help("\(call.host)\(call.path)")
				.frame(maxWidth: .infinity, alignment: .leading)
			Text(call.durationText)
				.font(.caption)
				.foregroundStyle(.secondary)
				.frame(width: NetworkConsoleConstants.Traffic.durationWidth, alignment: .trailing)
			NetworkMockedBadgeView(isMocked: call.isMocked)
		}
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.callRowPrefix + String(index))
	}
}
