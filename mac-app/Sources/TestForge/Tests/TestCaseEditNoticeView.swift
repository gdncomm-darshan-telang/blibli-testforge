import SwiftUI

struct TestCaseEditNoticeView: View {
	let notice: TestCaseEditNotice
	let isReverting: Bool
	let revert: () -> Void

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: notice.isDocumentChanged ? "exclamationmark.triangle.fill" : "pencil.circle.fill")
				.foregroundStyle(tint)
				.accessibilityHidden(true)
			Text(notice.text)
				.font(.callout)
				.fixedSize(horizontal: false, vertical: true)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testsEditNoticeText)
			Spacer(minLength: TestForgeConstants.Spacing.medium)
			Button {
				revert()
			} label: {
				ActionProgressLabel(title: String(localized: "Revert to document…"), busyTitle: String(localized: "Reverting…"), isBusy: isReverting)
			}
			.disabled(isReverting)
			.help("Drop your edits; runs use the document's text again")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsRevertEditButton)
		}
		.padding(TestForgeConstants.Spacing.medium)
		.background(tint.opacity(TestForgeConstants.Tests.badgeBackgroundOpacity), in: noticeShape)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsEditNotice)
	}

	private var noticeShape: RoundedRectangle {
		RoundedRectangle(cornerRadius: TestForgeConstants.Tests.editNoticeCornerRadius)
	}

	private var tint: Color {
		notice.isDocumentChanged ? .orange : .accentColor
	}
}
