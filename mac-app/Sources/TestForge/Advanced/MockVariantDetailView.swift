import SwiftUI

/// The selected rule's chosen answer, with the stored body decoded so a person can read it.
struct MockVariantDetailView: View {
	let detail: MockVariantDetailModel?

	var body: some View {
		Group {
			if let detail {
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
					Text(detail.ruleTitle)
						.font(.callout.monospaced())
						.lineLimit(1)
						.truncationMode(.middle)
					Text("Answer “\(detail.variantName)” · \(detail.summary)")
						.font(.callout)
						.foregroundStyle(.secondary)
					ScrollView {
						Text(detail.body)
							.font(.caption.monospaced())
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
				}
				.padding(TestForgeConstants.Spacing.medium)
			} else {
				EmptyStateView(content: emptyContent)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.fakeDataVariantDetail)
	}

	private var emptyContent: EmptyStateContent {
		EmptyStateContent(
			title: "Pick a rule",
			systemImage: "doc.text.magnifyingglass",
			message: "Select a rule to read the answer it gives the app."
		)
	}
}
