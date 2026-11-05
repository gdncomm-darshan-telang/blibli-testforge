import SwiftUI

/// The opening card (what is checked, why, how the page is set up) and the closing result card.
struct ExplainCardView: View {
	let card: ExplainCard
	let width: CGFloat

	var body: some View {
		VStack(alignment: .leading, spacing: width * ExplainOverlayConstants.Card.headingShare) {
			Text(card.title)
				.font(.system(size: width * ExplainOverlayConstants.Card.titleShare, weight: .bold))
				.foregroundStyle(.white)
				.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.cardTitle)
			ForEach(card.sections) { section in
				sectionView(section)
			}
			Spacer(minLength: 0)
		}
		.padding(.horizontal, width * ExplainOverlayConstants.Card.marginShare)
		.padding(.top, width * ExplainOverlayConstants.Card.topShare)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.background(ExplainOverlayConstants.Card.background)
		.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.card)
	}

	@ViewBuilder
	private func sectionView(_ section: ExplainCardSection) -> some View {
		VStack(alignment: .leading, spacing: width * 0.008) {
			Text(section.heading.uppercased())
				.font(.system(size: width * ExplainOverlayConstants.Card.headingShare, weight: .bold))
				.foregroundStyle(ExplainOverlayConstants.Card.accent)
				.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.cardHeading)
			Text(section.body)
				.font(.system(size: width * ExplainOverlayConstants.Card.bodyShare))
				.foregroundStyle(.white)
				.fixedSize(horizontal: false, vertical: true)
				.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.cardBody)
		}
	}
}
