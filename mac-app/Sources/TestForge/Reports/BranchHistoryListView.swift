import SwiftUI

struct BranchHistoryListView: View {
	let rows: [BranchRowModel]
	@Binding var selection: String?

	var body: some View {
		List(selection: $selection) {
			Section("History by branch") {
				ForEach(rows) { row in
					BranchHistoryRowView(row: row)
						.tag(row.id)
				}
			}
		}
		.listStyle(.inset)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.reportsBranchList)
		.tutorialAnchor(.reportsBranchList)
	}
}
