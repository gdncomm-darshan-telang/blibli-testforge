import SwiftUI

struct ReportPickerBarView: View {
	let runOptions: [ReportRunOption]
	let baseOptions: [ReportRunOption]
	@Binding var selectedRunId: String?
	@Binding var selectedBaseRunId: String?

	var body: some View {
		Grid(alignment: .leading, horizontalSpacing: TestForgeConstants.Spacing.medium, verticalSpacing: TestForgeConstants.Spacing.medium) {
			GridRow {
				Text("Run")
					.foregroundStyle(.secondary)
				Picker("Run", selection: $selectedRunId) {
					ForEach(runOptions) { option in
						Text(option.title).tag(Optional(option.id))
					}
				}
				.labelsHidden()
				.frame(maxWidth: TestForgeConstants.Reports.pickerMaxWidth, alignment: .leading)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.reportsRunPicker)
			}
			GridRow {
				Text("Compare with")
					.foregroundStyle(.secondary)
				Picker("Compare with", selection: $selectedBaseRunId) {
					Text("Automatic — develop, else the run before").tag(String?.none)
					Divider()
					ForEach(baseOptions) { option in
						Text(option.title).tag(Optional(option.id))
					}
				}
				.labelsHidden()
				.frame(maxWidth: TestForgeConstants.Reports.pickerMaxWidth, alignment: .leading)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.reportsComparePicker)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.reportsPickerBar)
		.tutorialAnchor(.reportsPickerBar)
	}
}
