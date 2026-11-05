import SwiftUI

struct ScanScreenListView: View {
	let screens: [ScanScreenRowModel]

	var body: some View {
		Group {
			if screens.isEmpty {
				EmptyStateView(content: Self.noScreensContent)
			} else {
				List(screens) { screen in
					ScanScreenRowView(screen: screen)
				}
				.listStyle(.inset)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.scanScreenList)
	}

	private static let noScreensContent = EmptyStateContent(
		title: "No screens marked",
		systemImage: "rectangle.stack",
		message: "Marked screens appear here."
	)
}
