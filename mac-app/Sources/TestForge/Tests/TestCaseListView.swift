import SwiftUI

struct TestCaseListView: View {
	let rows: [TestCaseRowModel]
	@Binding var selection: String?

	var body: some View {
		List(rows, selection: $selection) { row in
			TestCaseRowView(row: row)
				.tag(row.id)
		}
		.listStyle(.inset)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsList)
		.tutorialAnchor(.testsList)
	}
}
