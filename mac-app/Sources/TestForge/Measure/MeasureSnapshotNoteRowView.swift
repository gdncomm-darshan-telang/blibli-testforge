import SwiftUI

struct MeasureSnapshotNoteActions {
	let update: (String) -> Void
	let remove: () -> Void
}

struct MeasureSnapshotNoteRowView: View {
	let pin: MeasurePin
	let actions: MeasureSnapshotNoteActions

	var body: some View {
		HStack(alignment: .top, spacing: TestForgeConstants.Spacing.medium) {
			MeasurePinBadgeView(number: pin.id)
			TextField("Note for pin \(pin.id)", text: noteBinding, axis: .vertical)
				.textFieldStyle(.roundedBorder)
				.lineLimit(1...4)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.measureSnapshotNotePrefix + String(pin.id))
			Button(action: actions.remove) {
				Image(systemName: "trash")
			}
			.buttonStyle(.borderless)
			.help("Remove this pin")
			.accessibilityLabel("Remove pin \(pin.id)")
		}
		.accessibilityElement(children: .contain)
	}

	private var noteBinding: Binding<String> {
		let actions = actions
		let note = pin.note
		return Binding {
			note
		} set: { newValue in
			actions.update(newValue)
		}
	}
}
