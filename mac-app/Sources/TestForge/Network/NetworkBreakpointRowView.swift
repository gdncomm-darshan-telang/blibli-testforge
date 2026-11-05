import SwiftUI

struct NetworkBreakpointRowControl {
	let isRemoving: Bool
	let isDisabled: Bool
	let remove: () -> Void
}

struct NetworkBreakpointRowView: View {
	let breakpoint: BreakpointRowModel
	let index: Int
	let control: NetworkBreakpointRowControl

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: "pause.circle")
				.foregroundStyle(.orange)
			VStack(alignment: .leading, spacing: 0) {
				Text(breakpoint.endpoint)
					.font(.callout.monospaced())
					.lineLimit(1)
					.truncationMode(.middle)
				Text(breakpoint.detailText)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			Spacer()
			if control.isRemoving {
				ProgressView()
					.controlSize(.small)
					.help("Removing…")
					.accessibilityLabel(Text("Removing…"))
					.accessibilityIdentifier(TestForgeConstants.Accessibility.networkBreakpointRemovingPrefix + String(index))
			} else {
				Button("Remove", systemImage: "xmark.circle.fill", action: control.remove)
					.labelStyle(.iconOnly)
					.buttonStyle(.borderless)
					.disabled(control.isDisabled)
					.help("Stop holding this endpoint (calls held now stay held)")
					.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.breakpointRemovePrefix + String(index))
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.breakpointRowPrefix + String(index))
	}
}
