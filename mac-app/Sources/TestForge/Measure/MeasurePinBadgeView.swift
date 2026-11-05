import SwiftUI

struct MeasurePinBadgeView: View {
	let number: Int

	var body: some View {
		Text("\(number)")
			.font(.system(size: TestForgeConstants.MeasureSnapshot.pinFontSize, weight: .bold).monospacedDigit())
			.foregroundStyle(Color.white)
			.frame(width: TestForgeConstants.MeasureSnapshot.pinSize, height: TestForgeConstants.MeasureSnapshot.pinSize)
			.background(Circle().fill(TestForgeConstants.MeasureSnapshot.pinColor))
			.overlay(Circle().strokeBorder(Color.white, lineWidth: TestForgeConstants.MeasureSnapshot.pinBorderWidth))
			.accessibilityElement(children: .combine)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.measureSnapshotPinPrefix + String(number))
	}
}
