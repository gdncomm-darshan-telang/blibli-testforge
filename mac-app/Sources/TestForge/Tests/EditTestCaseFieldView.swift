import SwiftUI

struct EditTestCaseFieldView: View {
	let title: LocalizedStringResource
	let fieldId: String
	@Binding var text: String

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text(title)
				.font(.headline)
			TextEditor(text: $text)
				.font(.body)
				.frame(minHeight: TestForgeConstants.Tests.editFieldMinHeight)
				.scrollContentBackground(.hidden)
				.padding(TestForgeConstants.Spacing.small)
				.background(.background, in: RoundedRectangle(cornerRadius: TestForgeConstants.Tests.editNoticeCornerRadius))
				.overlay {
					RoundedRectangle(cornerRadius: TestForgeConstants.Tests.editNoticeCornerRadius)
						.strokeBorder(.separator)
				}
				.accessibilityLabel(Text(title))
				.accessibilityIdentifier(TestForgeConstants.Accessibility.editSheetFieldPrefix + fieldId)
		}
	}
}
