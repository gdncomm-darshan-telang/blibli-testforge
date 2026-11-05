import AppKit

/// Draws annotation strokes into a screenshot at its full pixel size, and the same paths for the on-screen canvas.
enum AnnotationRenderer {
	/// Line width as a share of the image's shorter side, so marks look the same on any screenshot.
	static let lineWidthShare: CGFloat = 0.008

	static let arrowHeadShare: CGFloat = 0.045
	static let arrowHeadAngle: CGFloat = .pi / 7

	/// The annotated image encoded like the original file (JPEG for .jpg/.jpeg, else PNG); nil when it can't be drawn.
	static func render(image: NSImage, strokes: [AnnotationStroke], fileExtension: String) -> Data? {
		guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
			let context = CGContext(
				data: nil,
				width: cgImage.width,
				height: cgImage.height,
				bitsPerComponent: 8,
				bytesPerRow: 0,
				space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
			)
		else {
			return nil
		}
		let size = CGSize(width: cgImage.width, height: cgImage.height)
		context.draw(cgImage, in: CGRect(origin: .zero, size: size))
		// Strokes are measured from the top left; Core Graphics draws from the bottom left.
		context.translateBy(x: 0, y: size.height)
		context.scaleBy(x: 1, y: -1)
		for stroke in strokes {
			context.setStrokeColor(stroke.color.nsColor.cgColor)
			context.setLineWidth(lineWidth(for: size))
			context.setLineCap(.round)
			context.setLineJoin(.round)
			context.addPath(path(for: stroke, in: CGRect(origin: .zero, size: size)))
			context.strokePath()
		}
		guard let annotated = context.makeImage() else {
			return nil
		}
		let representation = NSBitmapImageRep(cgImage: annotated)
		let isJPEG = ["jpg", "jpeg"].contains(fileExtension.lowercased())
		return representation.representation(using: isJPEG ? .jpeg : .png, properties: [:])
	}

	static func lineWidth(for size: CGSize) -> CGFloat {
		max(min(size.width, size.height) * lineWidthShare, 1)
	}

	/// The stroke's path inside `rect`, which is where the image is drawn (top-left origin).
	static func path(for stroke: AnnotationStroke, in rect: CGRect) -> CGPath {
		let points = stroke.points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
		let path = CGMutablePath()
		guard let first = points.first,
			let last = points.last
		else {
			return path
		}
		switch stroke.tool {
			case .pen:
				path.addLines(between: points)
			case .box:
				path.addRect(CGRect(x: min(first.x, last.x), y: min(first.y, last.y), width: abs(last.x - first.x), height: abs(last.y - first.y)))
			case .arrow:
				addArrow(to: path, from: first, to: last, headLength: min(rect.width, rect.height) * arrowHeadShare)
		}
		return path
	}

	private static func addArrow(to path: CGMutablePath, from start: CGPoint, to end: CGPoint, headLength: CGFloat) {
		path.move(to: start)
		path.addLine(to: end)
		let angle = atan2(end.y - start.y, end.x - start.x)
		for side in [arrowHeadAngle, -arrowHeadAngle] {
			let headAngle = angle + .pi + side
			path.move(to: end)
			path.addLine(to: CGPoint(x: end.x + cos(headAngle) * headLength, y: end.y + sin(headAngle) * headLength))
		}
	}
}
