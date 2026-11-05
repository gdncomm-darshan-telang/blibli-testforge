import SwiftUI

struct ResultCaseListView: View {
	let rows: [ResultCaseRowModel]
	@Binding var selection: Int?
	let showProofInFinder: (URL) -> Void

	var body: some View {
		List(rows, selection: $selection) { row in
			ResultCaseRowView(row: row)
				.tag(row.id)
				.contextMenu {
					proofMenuItem(proofURL: row.proofLocationURL)
				}
		}
		.listStyle(.inset)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsCaseList)
		.tutorialAnchor(.resultsCaseList)
	}

	@ViewBuilder
	private func proofMenuItem(proofURL: URL?) -> some View {
		if let proofURL {
			Button {
				showProofInFinder(proofURL)
			} label: {
				Label("Show in Finder", systemImage: "folder")
			}
		} else {
			Label("No proof saved for this case", systemImage: "folder.badge.questionmark")
		}
	}
}
