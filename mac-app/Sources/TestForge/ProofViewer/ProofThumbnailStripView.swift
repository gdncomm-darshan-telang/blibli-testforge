import SwiftUI

struct ProofThumbnailStripView: View {
	let items: [ProofMediaItem]
	let selectedIndex: Int?
	let select: (Int) -> Void

	var body: some View {
		ScrollView(.horizontal) {
			LazyHStack(spacing: TestForgeConstants.Spacing.medium) {
				ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
					thumbnail(item: item, index: index)
				}
			}
			.padding(TestForgeConstants.Spacing.medium)
		}
		.frame(height: TestForgeConstants.ProofViewer.stripHeight)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerStrip)
	}

	private func thumbnail(item: ProofMediaItem, index: Int) -> some View {
		Button {
			select(index)
		} label: {
			preview(item: item)
				.frame(width: TestForgeConstants.ProofViewer.thumbnailWidth, height: TestForgeConstants.ProofViewer.thumbnailHeight)
				.clipShape(RoundedRectangle(cornerRadius: TestForgeConstants.ProofViewer.thumbnailCornerRadius))
				.overlay(
					RoundedRectangle(cornerRadius: TestForgeConstants.ProofViewer.thumbnailCornerRadius)
						.strokeBorder(index == selectedIndex ? Color.accentColor : Color.clear, lineWidth: TestForgeConstants.ProofViewer.selectionBorderWidth)
				)
		}
		.buttonStyle(.plain)
		.help(item.name)
		.accessibilityLabel(item.name)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.proofViewerThumbnailPrefix + String(index))
	}

	@ViewBuilder
	private func preview(item: ProofMediaItem) -> some View {
		switch item.kind {
			case .image:
				AsyncImage(url: item.url) { phase in
					switch phase {
						case .success(let image):
							image
								.resizable()
								.scaledToFill()
						case .failure:
							Image(systemName: "photo.badge.exclamationmark")
								.foregroundStyle(.secondary)
						default:
							ProgressView()
								.controlSize(.small)
					}
				}
			case .video:
				Image(systemName: "film")
					.font(.title2)
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.background(Color.primary.opacity(TestForgeConstants.ProofViewer.videoTileOpacity))
		}
	}
}
