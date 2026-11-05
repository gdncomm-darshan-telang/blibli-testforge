import SwiftUI

struct SimulatorDisplaySectionView: View {
	@ObservedObject var viewModel: SimulatorControlViewModel

	var body: some View {
		SimulatorCardView(card: Self.card) {
			Toggle(isOn: blendedLayers) {
				Label("Color Blended Layers", systemImage: "square.3.layers.3d")
			}
			.toggleStyle(.switch)
			.disabled(!viewModel.canAct || viewModel.isBlendedLayersOn == nil)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorBlendedToggle)
			.tutorialAnchor(.simulatorBlendedToggle)
		}
	}

	private var blendedLayers: Binding<Bool> {
		let viewModel = viewModel
		return Binding {
			viewModel.isBlendedLayersOn ?? false
		} set: { isOn in
			viewModel.setBlendedLayers(isOn: isOn)
		}
	}
}

private extension SimulatorDisplaySectionView {
	static let card = SimulatorCard(
		name: "Display",
		title: "Display",
		systemImage: "paintpalette.fill",
		tint: .purple,
		footer: "Tints every layer: green is opaque, red is blended. Needs a booted device. Measure puts it back the way you left it."
	)
}
