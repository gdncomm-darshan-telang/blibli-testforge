import SwiftUI

struct SimulatorToolbarActions {
	let measure: () -> Void
}

/// Measure and the step-outline switch, grouped in the main window's toolbar.
struct SimulatorToolbarView: View {
	@Binding var isOutlineOn: Bool
	let actions: SimulatorToolbarActions

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.small) {
			Toggle(isOn: $isOutlineOn) {
				Label("Outline steps", systemImage: "viewfinder")
			}
			.toggleStyle(.button)
			.help("Outline, on the Simulator, the element each replay step acts on")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.outlineToggle)
			.tutorialAnchor(.outlineToggle)
			Button(action: actions.measure) {
				Label("Measure", systemImage: "ruler")
			}
			.help("Open Measure: sizes and spacing of the screen on the Simulator")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.measureButton)
			.tutorialAnchor(.measureButton)
		}
		.labelStyle(.iconOnly)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.simulatorToolbar)
	}

}
