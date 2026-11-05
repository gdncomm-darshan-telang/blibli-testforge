import AppKit
import CoreImage.CIFilterBuiltins

/// A crisp QR code for a link, so the phone's camera opens the session in the Claude app.
enum QRCodeRenderer {
	private static let scale: CGFloat = 8

	static func image(for url: URL) -> NSImage? {
		let filter = CIFilter.qrCodeGenerator()
		filter.message = Data(url.absoluteString.utf8)
		filter.correctionLevel = "M"
		guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else {
			return nil
		}
		let representation = NSCIImageRep(ciImage: output)
		let image = NSImage(size: representation.size)
		image.addRepresentation(representation)
		return image
	}
}
