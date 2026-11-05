import CoreGraphics
import Vision

/// Where text is drawn on the screenshot, one box per line, in device points (D-143). Read from the pixels with
/// Vision, so text the app never exposes to Accessibility (a label inside an unidentified strip) is still known.
enum TextRegionDetector {
	static func lineBoxes(in image: CGImage, screenSize: CGSize) -> [CGRect] {
		let request = VNRecognizeTextRequest()
		request.recognitionLevel = .fast
		request.usesLanguageCorrection = false
		let handler = VNImageRequestHandler(cgImage: image, options: [:])
		do {
			try handler.perform([request])
		} catch {
			return []
		}
		let observations = request.results ?? []
		return observations.map { observation in
			pointRect(fromNormalized: observation.boundingBox, screenSize: screenSize)
		}
	}

	/// Vision's boxes are normalised with the origin at the bottom left; Measure's points start at the top left.
	private static func pointRect(fromNormalized box: CGRect, screenSize: CGSize) -> CGRect {
		CGRect(
			x: box.minX * screenSize.width,
			y: (1 - box.maxY) * screenSize.height,
			width: box.width * screenSize.width,
			height: box.height * screenSize.height
		)
	}
}
