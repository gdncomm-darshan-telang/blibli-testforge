import SwiftUI

/// The closing card: a big check or cross, the verdict in its color, then which case ran.
struct ExplainResultCardView: View {
	let card: ExplainCard
	let outcome: DemoOutcome
	let width: CGFloat

	private var tint: Color {
		Color(nsColor: DemoLayout.color(for: outcome))
	}

	var body: some View {
		VStack(spacing: width * ExplainOverlayConstants.Result.spacingShare) {
			Image(systemName: outcome.symbolName)
				.symbolRenderingMode(.palette)
				.foregroundStyle(.white, tint)
				.font(.system(size: width * ExplainOverlayConstants.Result.symbolShare))
				.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.resultSymbol)
			Text(card.title)
				.font(.system(size: width * ExplainOverlayConstants.Result.titleShare, weight: .bold))
				.foregroundStyle(tint)
				.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.resultTitle)
			ForEach(card.sections) { section in
				sectionView(section)
			}
		}
		.multilineTextAlignment(.center)
		.frame(maxWidth: width * ExplainOverlayConstants.Result.textWidthShare)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(ExplainOverlayConstants.Card.background)
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.result)
	}

	private func sectionView(_ section: ExplainCardSection) -> some View {
		VStack(spacing: width * 0.008) {
			Text(section.heading.uppercased())
				.font(.system(size: width * ExplainOverlayConstants.Card.headingShare, weight: .semibold))
				.foregroundStyle(ExplainOverlayConstants.Result.secondary)
				.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.resultHeading)
			Text(section.body)
				.font(.system(size: width * ExplainOverlayConstants.Card.bodyShare))
				.foregroundStyle(.white)
				.fixedSize(horizontal: false, vertical: true)
				.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.resultBody)
		}
	}
}
