import SwiftUI

struct PhoneRemoteOutcomeLabelView: View {
	let outcome: PhoneRemoteOutcome
	let title: String

	var body: some View {
		switch outcome {
			case .succeeded:
				Label("\(title): OK", systemImage: "checkmark.circle.fill")
					.foregroundStyle(.green)
			case .warned(let message):
				Label("\(title): \(message)", systemImage: "exclamationmark.triangle.fill")
					.foregroundStyle(.orange)
			case .failed(let message):
				Label("\(title): \(message)", systemImage: "xmark.octagon.fill")
					.foregroundStyle(.red)
		}
	}
}
