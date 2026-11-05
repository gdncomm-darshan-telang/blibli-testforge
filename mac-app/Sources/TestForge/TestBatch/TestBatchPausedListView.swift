import SwiftUI

/// D-212: paused batches offered in the start sheet, so picking work back up is one click instead of a new batch.
struct TestBatchPausedListView: View {
	let batches: [TestBatchSummary]
	let actionState: TestBatchActionState
	let onResume: (TestBatchSummary) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text("Or pick up a paused batch")
				.font(.headline)
			ForEach(batches) { batch in
				HStack {
					Label(batch.name, systemImage: "pause.circle")
						.lineLimit(1)
						.truncationMode(.middle)
					Text("\(batch.itemCount) items")
						.foregroundStyle(.secondary)
					Spacer()
					Button {
						onResume(batch)
					} label: {
						ActionProgressLabel(title: String(localized: "Resume"), busyTitle: String(localized: "Resuming…"), isBusy: isResuming(batch: batch))
					}
					.disabled(isWorking)
					.help("Make “\(batch.name)” active again; new work and proof join it")
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchSheetResumePrefix + batch.id)
				}
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testBatchPausedList)
	}

	private var isWorking: Bool {
		guard case .working = actionState else {
			return false
		}
		return true
	}

	private func isResuming(batch: TestBatchSummary) -> Bool {
		actionState == .working(.resume(batchId: batch.id))
	}
}
