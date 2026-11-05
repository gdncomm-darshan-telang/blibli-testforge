import SwiftUI

/// Shows or hides the dashed borders of views without identifiers; while shown, a picker sets their colour.
struct MeasureLayerBorderControlsView: View {
	@ObservedObject var viewModel: MeasureViewModel

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.small) {
			Toggle(isOn: $viewModel.showsUnidentifiedBorders) {
				Label("Views without IDs", systemImage: "square.dashed")
			}
			.toggleStyle(.button)
			.labelStyle(.titleAndIcon)
			.help("Show dashed borders around views that have no accessibility identifier")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.measureLayerBordersToggle)
			.tutorialAnchor(.measureLayerBorders)
			if viewModel.showsUnidentifiedBorders {
				ColorPicker("Border colour", selection: $viewModel.unidentifiedBorderColor, supportsOpacity: false)
					.labelsHidden()
					.help("Colour of the dashed borders")
					.accessibilityIdentifier(TestForgeConstants.Accessibility.measureLayerBorderColor)
			}
		}
		.accessibilityElement(children: .contain)
	}
}
