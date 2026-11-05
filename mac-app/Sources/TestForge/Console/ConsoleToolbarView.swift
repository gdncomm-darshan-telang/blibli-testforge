import SwiftUI

struct ConsoleToolbarView: View {
	@ObservedObject var viewModel: ConsoleSectionViewModel

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Picker("Source", selection: $viewModel.filter) {
				ForEach(ConsoleFilter.allCases) { filter in
					Text(filter.title)
						.tag(filter)
				}
			}
			.pickerStyle(.segmented)
			.labelsHidden()
			.fixedSize()
			.accessibilityIdentifier(TestForgeConstants.Accessibility.consoleFilter)
			.tutorialAnchor(.consoleFilter)
			Spacer()
			TextField("Search", text: $viewModel.searchText)
				.textFieldStyle(.roundedBorder)
				.frame(maxWidth: TestForgeConstants.Console.searchFieldWidth)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.consoleSearch)
				.tutorialAnchor(.consoleSearch)
			Button {
				viewModel.copyVisibleLines()
			} label: {
				Image(systemName: "doc.on.doc")
			}
			.help("Copy the lines shown")
			.accessibilityLabel("Copy the lines shown")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.consoleCopy)
			.tutorialAnchor(.consoleCopy)
			Button {
				viewModel.clear()
			} label: {
				Image(systemName: "trash")
			}
			.help("Clear the console")
			.accessibilityLabel("Clear the console")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.consoleClear)
		}
		.buttonStyle(.borderless)
		.padding(.horizontal, TestForgeConstants.Spacing.medium)
		.padding(.vertical, TestForgeConstants.Spacing.small)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.consoleToolbar)
	}
}
