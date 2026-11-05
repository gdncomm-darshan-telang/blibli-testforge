import SwiftUI

struct MacroStepRowView: View {
	let step: MacroStepModel

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			Text("\(step.number)")
				.font(.caption.monospacedDigit())
				.foregroundStyle(.secondary)
			Text(step.action)
				.font(.caption.monospaced().bold())
				.frame(width: TestForgeConstants.Advanced.methodWidth, alignment: .leading)
			Text(step.text)
				.font(.callout)
				.textSelection(.enabled)
				.frame(maxWidth: .infinity, alignment: .leading)
			if step.hasWeakTarget {
				Image(systemName: "exclamationmark.triangle")
					.foregroundStyle(.orange)
					.help("Found by its visible text, not an accessibility id, so copy changes can break it")
			}
		}
	}
}
