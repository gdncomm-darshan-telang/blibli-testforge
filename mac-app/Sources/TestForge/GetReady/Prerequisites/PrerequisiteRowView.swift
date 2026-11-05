import SwiftUI

struct PrerequisiteRowView: View {
	let row: PrerequisiteRowModel
	let onCopy: (String) -> Void

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: row.statusSymbol)
				.foregroundStyle(color)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(row.label)
					.font(.body.weight(.medium))
				Text(row.detail)
					.font(.caption)
					.foregroundStyle(.secondary)
					.textSelection(.enabled)
				if let howTo = row.howTo {
					HStack(spacing: TestForgeConstants.Spacing.small) {
						Text(howTo)
							.font(.caption.monospaced())
							.textSelection(.enabled)
							.fixedSize(horizontal: false, vertical: true)
						Button("Copy", systemImage: "doc.on.doc") {
							onCopy(howTo)
						}
						.labelStyle(.iconOnly)
						.buttonStyle(.borderless)
						.help("Copy this, then run it in Terminal or Claude Code")
						.accessibilityIdentifier(TestForgeConstants.Accessibility.prerequisiteCopyPrefix + row.id)
					}
				}
			}
		}
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.prerequisiteRowPrefix + row.id)
	}

	private var color: Color {
		switch row.tone {
			case .passed:
				return .green
			case .failed:
				return .red
			case .neutral, .notRun:
				return .orange
		}
	}
}
