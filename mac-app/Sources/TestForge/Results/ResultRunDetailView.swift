import SwiftUI

struct ResultRunDetailView: View {
	let detail: ResultRunDetailModel
	let controls: ResultRunControls
	@Binding var selection: Int?

	var body: some View {
		VStack(spacing: 0) {
			ResultRunHeaderView(header: detail.header, controls: controls)
			Divider()
			ResultCaseListView(rows: detail.cases, selection: $selection, showProofInFinder: controls.actions.showProofInFinder)
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.resultsRunDetail)
	}
}
