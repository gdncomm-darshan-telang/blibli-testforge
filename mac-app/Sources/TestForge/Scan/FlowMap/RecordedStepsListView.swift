import SwiftUI

/// Every gesture in order; these become the macro's steps.
struct RecordedStepsListView: View {
	let rows: [RecordedStepRowModel]
	let remove: (String) -> Void
	let select: (String) -> Void

	var body: some View {
		if rows.isEmpty {
			ContentUnavailableView(
				"No steps yet",
				systemImage: "hand.tap",
				description: Text("Record, then tap through the app in the Simulator.")
			)
			.accessibilityIdentifier(MacroRecorderConstants.Accessibility.stepsEmpty)
		} else {
			List(rows) { row in
				RecordedStepRowView(row: row) {
					remove(row.id)
				}
				.contentShape(Rectangle())
				.onTapGesture {
					if let nextScreenId = row.nextScreenId {
						select(nextScreenId)
					}
				}
			}
			.accessibilityIdentifier(MacroRecorderConstants.Accessibility.steps)
		}
	}
}
