import SwiftUI

struct ConsoleLineRowView: View {
	let line: ConsoleLine

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			Text(line.source.rawValue)
				.foregroundStyle(.secondary)
				.frame(width: TestForgeConstants.Console.sourceTagWidth, alignment: .leading)
			Text(line.text)
				.textSelection(.enabled)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
		.font(.system(.caption, design: .monospaced))
		.accessibilityIdentifier(TestForgeConstants.Accessibility.consoleLine)
	}
}
