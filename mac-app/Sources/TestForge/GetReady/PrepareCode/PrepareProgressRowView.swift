import SwiftUI

struct PrepareProgressRowView: View {
	let line: PrepareProgressLine

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			icon
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(line.text)
					.font(.callout)
				if let toolOutput = line.toolOutput {
					Text(toolOutput)
						.font(.caption.monospaced())
						.foregroundStyle(.secondary)
						.lineLimit(1)
						.truncationMode(.middle)
				}
			}
		}
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.prepareCodeProgressPrefix + String(line.id))
	}

	@ViewBuilder
	private var icon: some View {
		switch line.kind {
			case .doing:
				ProgressView()
					.controlSize(.small)
			case .done:
				Image(systemName: "checkmark.circle.fill")
					.foregroundStyle(.green)
					.accessibilityHidden(true)
			case .failed:
				Image(systemName: "xmark.circle.fill")
					.foregroundStyle(.red)
					.accessibilityHidden(true)
		}
	}
}
