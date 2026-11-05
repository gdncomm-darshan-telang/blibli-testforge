import SwiftUI

struct BundleCaseMockRowView: View {
	let row: BundleCaseMockRowModel
	let onArm: (String) -> Void

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(row.caseText)
					.font(.callout.weight(.medium))
				Text(row.mocksText)
					.font(.caption.monospaced())
					.foregroundStyle(.secondary)
					.textSelection(.enabled)
			}
			Spacer()
			if row.canArm {
				Button("Set up mocks") {
					onArm(row.id)
				}
				.controlSize(.small)
				.help("Switch on the responses this case ran with, then test it by hand on the simulator")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsBundleArmPrefix + row.id)
			}
		}
	}
}
