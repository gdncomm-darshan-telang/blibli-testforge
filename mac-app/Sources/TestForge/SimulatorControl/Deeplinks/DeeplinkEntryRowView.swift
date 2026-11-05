import SwiftUI

struct DeeplinkEntryActions {
	let open: (String) -> Void
	let remove: (String) -> Void
}

/// A saved link or recent open: re-open it, or (saved only) remove it.
struct DeeplinkEntryRowView: View {
	let row: DeeplinkEntryRow
	let isOpenEnabled: Bool
	let actions: DeeplinkEntryActions

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			VStack(alignment: .leading, spacing: 0) {
				Text(row.title)
					.lineLimit(1)
					.truncationMode(.middle)
				if let detail = row.detail {
					Text(detail)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}
			}
			Spacer()
			Button {
				actions.open(row.url)
			} label: {
				Image(systemName: "arrow.up.forward.app")
			}
			.buttonStyle(.borderless)
			.disabled(!isOpenEnabled)
			.help(row.url)
			.accessibilityIdentifier(rowIdentifier + TestForgeConstants.Accessibility.deeplinkEntryOpenSuffix)
			if row.isSaved {
				Button {
					actions.remove(row.id)
				} label: {
					Image(systemName: "trash")
				}
				.buttonStyle(.borderless)
				.help("Remove from saved links")
				.accessibilityIdentifier(rowIdentifier + TestForgeConstants.Accessibility.deeplinkEntryRemoveSuffix)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(rowIdentifier)
	}

	private var rowIdentifier: String {
		TestForgeConstants.Accessibility.deeplinkEntryRowPrefix + row.id
	}
}
