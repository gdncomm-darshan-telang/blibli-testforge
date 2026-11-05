import SwiftUI

/// The answer to one command: a plain verdict line, then the raw JSON the harness returned.
struct DriverResultView: View {
	let result: PhoneRemoteResult?

	var body: some View {
		Group {
			if let result {
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
					PhoneRemoteOutcomeLabelView(outcome: result.outcome, title: result.title)
					ScrollView {
						Text(result.output)
							.font(.caption.monospaced())
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
				}
				.padding(TestForgeConstants.Spacing.medium)
			} else {
				EmptyStateView(content: EmptyStateContent(
					title: "No command sent yet",
					systemImage: "iphone.gen3.radiowaves.left.and.right",
					message: "Pick a command, fill its details and press Send."
				))
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.phoneRemoteResult)
		.tutorialAnchor(.phoneRemoteResult)
	}
}
