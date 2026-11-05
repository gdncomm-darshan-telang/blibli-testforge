import SwiftUI

struct ResultRunListView: View {
	let rows: [ResultRunRowModel]
	@Binding var selection: String?

	var body: some View {
		List(rows, selection: $selection) { row in
			ResultRunRowView(row: row)
				.tag(row.id)
		}
		.listStyle(.inset)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsRunList)
		.tutorialAnchor(.resultsRunList)
	}
}
