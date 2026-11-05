import CoreGraphics

/// Maps device points to where the Simulator draws them on the Mac, from the screen group's rect and the device's size.
struct ScreenMapping: Equatable {
	/// Wider than rounding error, narrower than any bezel or toolbar a wrong rect would include.
	static let aspectTolerance: CGFloat = 0.02

	let screenFrame: CGRect
	let devicePoints: CGSize

	/// A rect whose shape isn't the device's (a bezel counted in, a half-loaded window) would put every outline in the wrong place.
	var isCalibrated: Bool {
		guard screenFrame.width > 0,
			screenFrame.height > 0,
			devicePoints.width > 0,
			devicePoints.height > 0
		else {
			return false
		}
		let screenAspect = screenFrame.width / screenFrame.height
		let deviceAspect = devicePoints.width / devicePoints.height
		return abs(screenAspect - deviceAspect) / deviceAspect <= Self.aspectTolerance
	}

	private var scale: CGFloat {
		screenFrame.width / devicePoints.width
	}

	func macRect(forDeviceRect deviceRect: CGRect) -> CGRect {
		CGRect(
			x: screenFrame.minX + deviceRect.minX * scale,
			y: screenFrame.minY + deviceRect.minY * scale,
			width: deviceRect.width * scale,
			height: deviceRect.height * scale
		)
	}

	func deviceRect(forMacRect macRect: CGRect) -> CGRect {
		CGRect(
			x: (macRect.minX - screenFrame.minX) / scale,
			y: (macRect.minY - screenFrame.minY) / scale,
			width: macRect.width / scale,
			height: macRect.height / scale
		)
	}
}

/// Accessibility frames use a top-left origin on the primary display; AppKit windows use a bottom-left one.
enum ScreenCoordinates {
	static func appKitRect(fromAccessibilityRect rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
		CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
	}

	static func accessibilityRect(fromAppKitRect rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
		CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
	}
}
