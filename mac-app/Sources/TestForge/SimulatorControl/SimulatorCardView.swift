import SwiftUI

struct SimulatorCard {
	let name: String
	let title: LocalizedStringKey?
	let systemImage: String
	let tint: Color
	let footer: LocalizedStringKey?
}

/// The Simulator screen's card: a tinted symbol header, its controls, and an optional footnote.
struct SimulatorCardView<Content: View>: View {
	let card: SimulatorCard
	@ViewBuilder let content: Content

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			header
			content
			if let footer = card.footer {
				Text(footer)
					.font(.caption)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.padding(TestForgeConstants.Spacing.large)
		.frame(maxWidth: .infinity, alignment: .topLeading)
		.background(
			RoundedRectangle(cornerRadius: TestForgeConstants.SimulatorControl.cardCornerRadius)
				.fill(Color(nsColor: .controlBackgroundColor))
		)
		.overlay(
			RoundedRectangle(cornerRadius: TestForgeConstants.SimulatorControl.cardCornerRadius)
				.strokeBorder(Color.primary.opacity(TestForgeConstants.SimulatorControl.cardBorderOpacity))
		)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorCardPrefix + card.name)
	}

	@ViewBuilder
	private var header: some View {
		if let title = card.title {
			HStack(spacing: TestForgeConstants.Spacing.medium) {
				Image(systemName: card.systemImage)
					.font(.callout.weight(.semibold))
					.foregroundStyle(card.tint)
					.frame(width: TestForgeConstants.SimulatorControl.headerIconSize, height: TestForgeConstants.SimulatorControl.headerIconSize)
					.background(
						RoundedRectangle(cornerRadius: TestForgeConstants.SimulatorControl.headerIconCornerRadius)
							.fill(card.tint.opacity(TestForgeConstants.SimulatorControl.headerIconOpacity))
					)
				Text(title)
					.font(.headline)
			}
			.accessibilityElement(children: .combine)
			.accessibilityIdentifier(headerIdentifier)
		}
	}

	private var headerIdentifier: String {
		TestForgeConstants.Accessibility.simulatorCardPrefix + card.name + TestForgeConstants.Accessibility.simulatorCardHeaderSuffix
	}
}
