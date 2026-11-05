import SwiftUI

struct GitStatusCardView: View {
	let content: GitStatusContent

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Label(content.title, systemImage: "arrow.triangle.branch")
				.font(.headline.monospaced())
				.accessibilityIdentifier(TestForgeConstants.Accessibility.gitCurrentBranch)
			if !content.subject.isEmpty {
				Text(content.subject)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			Text(content.syncText)
				.font(.callout)
				.foregroundStyle(content.isBehind ? .orange : .primary)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.gitSync)
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				Text(content.changesText)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.gitChanges)
				Text(content.fetchedText)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.gitFetchedAt)
			}
			.font(.caption)
			.foregroundStyle(.secondary)
			if let warning = content.warning {
				Label(warning, systemImage: "exclamationmark.triangle.fill")
					.font(.callout)
					.foregroundStyle(.orange)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.gitWarning)
			}
			if !content.files.isEmpty {
				DisclosureGroup("Changed files") {
					ForEach(content.files) { file in
						Text("\(file.state) · \(file.path)")
							.font(.caption.monospaced())
							.textSelection(.enabled)
					}
				}
				.font(.caption)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.gitFiles)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(TestForgeConstants.Spacing.medium)
		.background(
			.quaternary.opacity(TestForgeConstants.GetReady.gitCardOpacity),
			in: RoundedRectangle(cornerRadius: TestForgeConstants.GetReady.gitCardCornerRadius)
		)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.gitStatusCard)
	}
}
