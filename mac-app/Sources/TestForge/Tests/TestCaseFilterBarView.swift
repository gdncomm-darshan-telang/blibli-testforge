import SwiftUI

struct TestCaseFilterBarView: View {
	@Binding var filter: TestCaseFilter

	var body: some View {
		HStack {
			Picker("Show", selection: $filter) {
				ForEach(TestCaseFilter.allCases) { filterOption in
					Text(filterOption.title)
						.tag(filterOption)
				}
			}
			.pickerStyle(.menu)
			.fixedSize()
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsFilter)
			Spacer()
		}
		.padding(.horizontal, TestForgeConstants.Spacing.medium)
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsFilterBar)
		.tutorialAnchor(.testsFilterBar)
	}
}
