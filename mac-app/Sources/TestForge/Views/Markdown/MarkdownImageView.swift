import AppKit
import SwiftUI

/// A local proof image (file URL); other URLs, or a file that's gone, show the alt text instead.
struct MarkdownImageView: View {
	let image: MarkdownImage
	@Environment(\.openURL) private var openURL
	@State private var loaded: NSImage?

	var body: some View {
		Group {
			if let loaded {
				Image(nsImage: loaded)
					.resizable()
					.scaledToFit()
					.frame(maxWidth: MarkdownConstants.imageMaxWidth, maxHeight: MarkdownConstants.imageMaxHeight)
					.clipShape(RoundedRectangle(cornerRadius: MarkdownConstants.imageCornerRadius))
					.overlay {
						RoundedRectangle(cornerRadius: MarkdownConstants.imageCornerRadius)
							.strokeBorder(.separator)
					}
					.onTapGesture {
						open()
					}
			} else {
				Label(image.alt.isEmpty ? String(localized: "Image") : image.alt, systemImage: "photo")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
		.help(image.alt)
		.accessibilityLabel(image.alt)
		.accessibilityIdentifier(MarkdownConstants.Accessibility.imagePrefix + String(image.id))
		.task(id: image.url) {
			loaded = await Self.load(image.url)
		}
	}

	private func open() {
		guard let url = image.url else {
			return
		}
		openURL(url)
	}

	private static func load(_ url: URL?) async -> NSImage? {
		guard let url, url.isFileURL else {
			return nil
		}
		return await Task.detached(priority: .utility) {
			NSImage(contentsOf: url)
		}.value
	}
}
