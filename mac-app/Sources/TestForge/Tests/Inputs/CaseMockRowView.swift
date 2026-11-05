import SwiftUI

struct CaseMockRowActions {
	let copy: (String) -> Void
	let download: () -> Void
}

/// One mocked endpoint: its variant and status, the body folded away, Copy and Download.
struct CaseMockRowView: View {
	let row: CaseMockRowModel
	let actions: CaseMockRowActions
	@State private var isExpanded = false

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack(alignment: .firstTextBaseline) {
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
					Text(row.endpoint)
						.font(.callout.monospaced())
						.textSelection(.enabled)
					Text(row.detailText)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				Spacer(minLength: 0)
				if let body = row.body {
					Button("Copy") {
						actions.copy(body)
					}
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testsInputsCopyPrefix + row.id)
					Button("Download…", action: actions.download)
						.accessibilityIdentifier(TestForgeConstants.Accessibility.testsInputsDownloadPrefix + row.id)
				}
			}
			if let body = row.body {
				DisclosureGroup("Response body", isExpanded: $isExpanded) {
					ScrollView {
						Text(body)
							.font(.caption.monospaced())
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
					.frame(maxHeight: TestForgeConstants.Tests.inputsBodyMaxHeight)
				}
				.font(.caption)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsInputsMockPrefix + row.id)
	}
}
