import Foundation

/// A plain and a Color Blended Layers capture of the same screen, as PNG.
struct LayerCapturePair {
	let plain: Data
	let tinted: Data
}

enum LayerCaptureError: LocalizedError {
	case coreSimulatorUnavailable
	case deviceNotFound
	case screenshotFailed(String)

	var errorDescription: String? {
		switch self {
			case .coreSimulatorUnavailable:
				return String(localized: "Xcode's CoreSimulator couldn't be loaded, so layer colours aren't available.")
			case .deviceNotFound:
				return String(localized: "The simulator device wasn't found.")
			case .screenshotFailed(let message):
				return String(localized: "The simulator screenshot failed: \(message)")
		}
	}
}

protocol LayerCapturing: Sendable {
	/// Turns Color Blended Layers on for one capture and always puts it back the way it was.
	func capture(udid: String) async throws -> LayerCapturePair

	/// Turns it back on if the app quit mid-capture while the device had it on.
	func restoreIfInterrupted()
}

/// Uses CoreSimulator's own Core Animation debug switch (what Simulator › Debug › Color Blended Layers calls),
/// which works without bringing the Simulator to the front; screenshots come from `simctl io` as PNG.
struct SimulatorLayerCapture: LayerCapturing {
	/// Settle time after flipping the switch; the change showed up within 0.2 s in testing.
	private let settleNanoseconds: UInt64 = 400_000_000

	/// Names the device whose switch is off only for a capture; cleared once it is back on.
	private static let pendingRestoreKey = "layerCapture.pendingRestoreUDID"

	func capture(udid: String) async throws -> LayerCapturePair {
		let switcher = try BlendedLayersSwitch(udid: udid)
		let wasOn = switcher.isOn
		if wasOn {
			UserDefaults.standard.set(udid, forKey: Self.pendingRestoreKey)
		}
		defer {
			switcher.set(isOn: wasOn)
			UserDefaults.standard.removeObject(forKey: Self.pendingRestoreKey)
		}
		switcher.set(isOn: false)
		try await Task.sleep(nanoseconds: settleNanoseconds)
		let plain = try await screenshot(udid: udid)
		switcher.set(isOn: true)
		try await Task.sleep(nanoseconds: settleNanoseconds)
		let tinted = try await screenshot(udid: udid)
		return LayerCapturePair(plain: plain, tinted: tinted)
	}

	func restoreIfInterrupted() {
		guard let udid = UserDefaults.standard.string(forKey: Self.pendingRestoreKey) else {
			return
		}
		UserDefaults.standard.removeObject(forKey: Self.pendingRestoreKey)
		let switcher = try? BlendedLayersSwitch(udid: udid)
		switcher?.set(isOn: true)
	}

	private func screenshot(udid: String) async throws -> Data {
		try await SimctlScreenshot.png(udid: udid)
	}
}

/// CoreSimulator's Core Animation debug switch; option 2 is Color Blended Layers.
struct BlendedLayersSwitch {
	private typealias GetOptionFunction = @convention(c) (AnyObject, Selector, UInt32) -> Bool
	private typealias SetOptionFunction = @convention(c) (AnyObject, Selector, UInt32, Bool) -> Void

	private static let blendedLayersOption: UInt32 = 2

	private let device: NSObject

	var isOn: Bool {
		let selector = NSSelectorFromString("getCADebugOption:")
		guard let implementation = device.method(for: selector) else {
			return false
		}
		return unsafeBitCast(implementation, to: GetOptionFunction.self)(device, selector, Self.blendedLayersOption)
	}

	init(udid: String) throws {
		device = try CoreSimulatorDevices.handle(udid: udid)
	}

	func set(isOn: Bool) {
		let selector = NSSelectorFromString("setCADebugOption:enabled:")
		guard let implementation = device.method(for: selector) else {
			return
		}
		unsafeBitCast(implementation, to: SetOptionFunction.self)(device, selector, Self.blendedLayersOption, isOn)
	}
}
