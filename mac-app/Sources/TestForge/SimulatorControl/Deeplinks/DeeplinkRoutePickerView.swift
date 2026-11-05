import SwiftUI

struct DeeplinkRouteSearchContent {
	let selectedTitle: String?
	let matches: [DeeplinkRoute]
	let footnote: String?
}

struct DeeplinkRouteSearchActions {
	let select: (String) -> Void
	let clear: () -> Void
}

/// One search over the app's screens, matches listed right under it; picking one builds the link below.
struct DeeplinkRoutePickerView: View {
	@Binding var searchText: String
	let content: DeeplinkRouteSearchContent
	let actions: DeeplinkRouteSearchActions

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			if let title = content.selectedTitle {
				selectedRow(title: title)
			} else {
				searchField
				matchList
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkRoutePicker)
	}

	private var searchField: some View {
		TextField("Find a screen", text: $searchText, prompt: Text("Find an app screen to build its link — cart, search, order…"))
			.textFieldStyle(.roundedBorder)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkRouteSearchField)
	}

	@ViewBuilder
	private var matchList: some View {
		if !content.matches.isEmpty {
			VStack(alignment: .leading, spacing: 0) {
				ForEach(content.matches) { route in
					DeeplinkRouteMatchRowView(route: route) {
						actions.select(route.id)
					}
				}
			}
			.background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
			.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkRouteMatches)
		}
		if let footnote = content.footnote {
			Text(footnote)
				.font(.caption)
				.foregroundStyle(.secondary)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkRouteFootnote)
		}
	}

	private func selectedRow(title: String) -> some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Label("Screen: \(title)", systemImage: "rectangle.portrait.on.rectangle.portrait")
				.lineLimit(1)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkRouteSelected)
			Spacer()
			Button("Change screen", systemImage: "xmark.circle", action: actions.clear)
				.help("Clear the picked screen and its link, then search again or type a link yourself")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkRouteChange)
		}
	}
}
