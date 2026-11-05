import SwiftUI

/// The live view of a scan: the accessibility surface the harness reads from the Simulator right now.
struct ScanCurrentScreenView: View {
	let current: ScanCurrentModel?

	var body: some View {
		Group {
			if let current {
				currentContent(current: current)
			} else {
				EmptyStateView(content: Self.waitingContent)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.scanCurrentScreen)
	}

	private static let waitingContent = EmptyStateContent(
		title: "Reading the screen…",
		systemImage: "eye",
		message: "The first read takes a second or two."
	)

	private func currentContent(current: ScanCurrentModel) -> some View {
		ScrollView {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
				HStack(alignment: .firstTextBaseline) {
					Text("On screen now")
						.font(.headline)
					Spacer()
					if let changedAt = current.changedAt {
						Text("changed \(changedAt, style: .relative) ago")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
				Text(current.countsText)
					.font(.callout)
					.foregroundStyle(.secondary)
				if current.isTruncated {
					Label("Only the top of this screen was read. Scroll and mark again to record the rest.", systemImage: "scissors")
						.font(.callout)
						.foregroundStyle(.orange)
				}
				identifierGrid(identifiers: current.identifiers)
			}
			.padding(TestForgeConstants.Spacing.large)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}

	private func identifierGrid(identifiers: [String]) -> some View {
		LazyVGrid(columns: Self.identifierColumns, alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			ForEach(identifiers, id: \.self) { identifier in
				Text(identifier)
					.font(.caption.monospaced())
					.lineLimit(1)
					.truncationMode(.middle)
					.padding(.horizontal, TestForgeConstants.Spacing.small)
					.padding(.vertical, TestForgeConstants.Tests.badgeVerticalPadding)
					.background(.quaternary, in: RoundedRectangle(cornerRadius: TestForgeConstants.Scan.chipCornerRadius))
					.help(identifier)
			}
		}
	}

	private static let identifierColumns = [GridItem(.adaptive(minimum: TestForgeConstants.Scan.identifierChipMinWidth), alignment: .leading)]
}
