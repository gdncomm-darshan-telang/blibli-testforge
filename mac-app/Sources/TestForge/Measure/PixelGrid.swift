import CoreGraphics
import Foundation

struct PixelColor: Equatable {
	let red: Int
	let green: Int
	let blue: Int

	/// Largest single-channel difference; JPEG noise stays well under the detector's threshold.
	func difference(to other: PixelColor) -> Int {
		max(abs(red - other.red), abs(green - other.green), abs(blue - other.blue))
	}
}

/// The screenshot as raw RGBA, addressed in device points, so edge detection matches the layout numbers.
/// Equality is by capture, not by comparing megabytes of pixels.
struct PixelGrid: Equatable {
	let pixelsPerPoint: CGFloat
	let pointSize: CGSize

	let width: Int
	let height: Int

	private let captureId = UUID()
	private let bytes: [UInt8]

	init?(image: CGImage, screenSize: CGSize) {
		let pixelWidth = image.width
		let pixelHeight = image.height
		guard pixelWidth > 0,
			pixelHeight > 0,
			screenSize.width > 0
		else {
			return nil
		}
		var buffer = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
		let isDrawn = buffer.withUnsafeMutableBytes { pointer -> Bool in
			let context = CGContext(
				data: pointer.baseAddress,
				width: pixelWidth,
				height: pixelHeight,
				bitsPerComponent: 8,
				bytesPerRow: pixelWidth * 4,
				space: colorSpace,
				bitmapInfo: bitmapInfo
			)
			context?.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
			return context != nil
		}
		guard isDrawn else {
			return nil
		}
		width = pixelWidth
		height = pixelHeight
		bytes = buffer
		pixelsPerPoint = CGFloat(pixelWidth) / screenSize.width
		pointSize = screenSize
	}

	/// Color Blended Layers draws each pixel as half the content plus half the tint, so 2 × tinted − plain is the tint alone.
	/// Text and images cancel out; only layer boxes (and how many tinted layers stack there) remain.
	static func tintResidual(tinted: PixelGrid, plain: PixelGrid) -> PixelGrid? {
		guard tinted.width == plain.width,
			tinted.height == plain.height
		else {
			return nil
		}
		var residual = [UInt8](repeating: 255, count: tinted.bytes.count)
		for index in stride(from: 0, to: residual.count, by: 4) {
			for channel in 0..<3 {
				let value = 2 * Int(tinted.bytes[index + channel]) - Int(plain.bytes[index + channel])
				residual[index + channel] = UInt8(clamping: value)
			}
		}
		return PixelGrid(bytes: residual, width: tinted.width, height: tinted.height, pointSize: tinted.pointSize)
	}

	private init(bytes: [UInt8], width: Int, height: Int, pointSize: CGSize) {
		self.bytes = bytes
		self.width = width
		self.height = height
		self.pointSize = pointSize
		pixelsPerPoint = CGFloat(width) / pointSize.width
	}

	static func == (lhs: PixelGrid, rhs: PixelGrid) -> Bool {
		lhs.captureId == rhs.captureId
	}

	/// Pixel addressing for full-image passes; the caller keeps column and row in range.
	func color(column: Int, row: Int) -> PixelColor {
		let offset = (row * width + column) * 4
		return PixelColor(red: Int(bytes[offset]), green: Int(bytes[offset + 1]), blue: Int(bytes[offset + 2]))
	}

	/// Nil outside the image; rows are top-down, matching device coordinates.
	func color(at point: CGPoint) -> PixelColor? {
		let column = Int((point.x * pixelsPerPoint).rounded(.down))
		let row = Int((point.y * pixelsPerPoint).rounded(.down))
		guard column >= 0,
			column < width,
			row >= 0,
			row < height
		else {
			return nil
		}
		let offset = (row * width + column) * 4
		return PixelColor(red: Int(bytes[offset]), green: Int(bytes[offset + 1]), blue: Int(bytes[offset + 2]))
	}
}
