import SwiftUI

struct SetupToolRowView: View {
	let row: SetupToolRowModel
	let fix: () -> Void

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			statusIcon
				.frame(width: SetupConstants.Layout.statusIconWidth)
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(row.tool.title)
				detailText
					.font(.callout)
					.foregroundStyle(.secondary)
			}
			Spacer()
			if case .checked(.missing) = row.state {
				Button(row.tool.fix.title, action: fix)
					.accessibilityIdentifier(SetupConstants.Accessibility.toolFixPrefix + row.tool.rawValue)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(SetupConstants.Accessibility.toolRowPrefix + row.tool.rawValue)
	}

	@ViewBuilder
	private var statusIcon: some View {
		switch row.state {
			case .checking:
				ProgressView()
					.controlSize(.small)
			case .checked(.ready):
				Image(systemName: "checkmark.circle.fill")
					.foregroundStyle(.green)
			case .checked(.missing):
				Image(systemName: "xmark.circle.fill")
					.foregroundStyle(.red)
		}
	}

	@ViewBuilder
	private var detailText: some View {
		switch row.state {
			case .checking:
				Text("Checking…")
			case .checked(.ready(let detail)), .checked(.missing(let detail)):
				Text(detail)
		}
	}
}
