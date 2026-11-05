import Foundation

enum ProofMediaKind: Equatable {
	case image
	case video
}

struct ProofMediaItem: Equatable, Identifiable {
	private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]

	let url: URL
	let kind: ProofMediaKind

	var id: URL { url }

	var name: String { url.lastPathComponent }

	init(url: URL) {
		self.url = url
		kind = Self.videoExtensions.contains(url.pathExtension.lowercased()) ? .video : .image
	}
}

/// What Results asks the viewer to show: one case's proof, opened on the file that was clicked.
struct ProofViewerRequest: Equatable {
	let title: String
	let urls: [URL]
	let selectedURL: URL
}

/// `fit` follows the window; `scale` is a fixed zoom where 1 is the file's own pixel size in points.
enum ProofZoom: Equatable {
	case fit
	case scale(CGFloat)
}
