import SwiftUI

/// Bottom console like Xcode's debug area: raw lines, newest last, follows the tail.
struct ConsoleSectionView: View {
	@ObservedObject var viewModel: ConsoleSectionViewModel

	var body: some View {
		VStack(spacing: 0) {
			ConsoleToolbarView(viewModel: viewModel)
			Divider()
			ScrollViewReader { proxy in
				List(viewModel.visibleLines) { line in
					ConsoleLineRowView(line: line)
						.id(line.id)
				}
				.listStyle(.plain)
				.environment(\.defaultMinListRowHeight, 1)
				.onChange(of: viewModel.visibleLines.last?.id) { _, lastLineId in
					guard let lastLineId else {
						return
					}
					proxy.scrollTo(lastLineId, anchor: .bottom)
				}
			}
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.console)
		.tutorialAnchor(.console)
	}
}
