import SwiftUI

/// Floats over the canvas while views without identifiers are being found, then says what the pass added.
struct MeasureLayerPassBannerView: View {
	let state: LayerPassState

	var body: some View {
		content
			.font(.callout)
			.padding(.horizontal, TestForgeConstants.Spacing.medium)
			.padding(.vertical, TestForgeConstants.Spacing.small)
			.background(.regularMaterial, in: Capsule())
			.padding(TestForgeConstants.Spacing.medium)
			.accessibilityElement(children: .combine)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.measureLayerPass)
	}

	@ViewBuilder
	private var content: some View {
		switch state {
			case .idle:
				EmptyView()
			case .running:
				HStack(spacing: TestForgeConstants.Spacing.small) {
					ProgressView()
						.controlSize(.small)
					Text("Finding views without identifiers…")
				}
			case .finished(let addedCount):
				Label("\(addedCount) views without identifiers added", systemImage: "square.dashed")
			case .skipped(let reason):
				Label("Views without identifiers skipped: \(reason)", systemImage: "pause.circle")
					.foregroundStyle(.secondary)
			case .failed(let message):
				Label("Views without identifiers not found: \(message)", systemImage: "exclamationmark.triangle")
					.foregroundStyle(.orange)
		}
	}
}
