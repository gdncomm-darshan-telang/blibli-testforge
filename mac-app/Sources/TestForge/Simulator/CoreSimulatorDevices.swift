import AppKit

/// A simulator as CoreSimulator describes it, including its screen in points — no app or test runner needed.
struct CoreSimulatorDevice: Equatable {
	let udid: String
	let name: String
	let runtime: String
	let isBooted: Bool
	let screenPoints: CGSize

	/// How the Simulator titles this device's window ("iPhone 17 Pro Max – iOS 26.2").
	var windowTitle: String {
		"\(name) – \(runtime)"
	}
}

/// CoreSimulator is private, so it's reached through the Objective-C runtime.
enum CoreSimulatorDevices {
	private typealias ContextFunction = @convention(c) (AnyObject, Selector, NSString, UnsafeMutablePointer<NSError?>?) -> AnyObject?
	private typealias DeviceSetFunction = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<NSError?>?) -> AnyObject?

	private static let frameworkPath = "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator"
	private static let bootedState = 3

	static func all() throws -> [CoreSimulatorDevice] {
		try deviceObjects().map(describe(device:))
	}

	/// The private `SimDevice`, for calls such as the Core Animation debug switch.
	static func handle(udid: String) throws -> NSObject {
		let match = try deviceObjects().first { device in
			(device.value(forKey: "UDID") as? NSUUID)?.uuidString == udid
		}
		guard let match else {
			throw LayerCaptureError.deviceNotFound
		}
		return match
	}

	/// `mainScreenSize` is in pixels; dividing by `mainScreenScale` gives the points the app lays out in.
	private static func describe(device: NSObject) -> CoreSimulatorDevice {
		let deviceType = device.value(forKey: "deviceType") as? NSObject
		let pixels = (deviceType?.value(forKey: "mainScreenSize") as? NSValue)?.sizeValue ?? NSSize()
		let scale = (deviceType?.value(forKey: "mainScreenScale") as? NSNumber)?.doubleValue ?? 1
		let runtime = (device.value(forKey: "runtime") as? NSObject)?.value(forKey: "name") as? String ?? ""
		let divisor = scale > 0 ? scale : 1
		return CoreSimulatorDevice(
			udid: (device.value(forKey: "UDID") as? NSUUID)?.uuidString ?? "",
			name: device.value(forKey: "name") as? String ?? "",
			runtime: runtime,
			isBooted: (device.value(forKey: "state") as? NSNumber)?.intValue == bootedState,
			screenPoints: CGSize(width: pixels.width / divisor, height: pixels.height / divisor)
		)
	}

	private static func deviceObjects() throws -> [NSObject] {
		guard dlopen(frameworkPath, RTLD_NOW) != nil,
			let contextClass = NSClassFromString("SimServiceContext") as? NSObject.Type,
			let context = serviceContext(contextClass: contextClass),
			let deviceSet = deviceSet(context: context)
		else {
			throw LayerCaptureError.coreSimulatorUnavailable
		}
		return deviceSet.value(forKey: "devices") as? [NSObject] ?? []
	}

	private static func serviceContext(contextClass: NSObject.Type) -> NSObject? {
		let selector = NSSelectorFromString("sharedServiceContextForDeveloperDir:error:")
		guard let method = class_getClassMethod(contextClass, selector) else {
			return nil
		}
		let implementation = method_getImplementation(method)
		let developerDirectory = developerDirectoryPath() as NSString
		return unsafeBitCast(implementation, to: ContextFunction.self)(contextClass, selector, developerDirectory, nil) as? NSObject
	}

	private static func deviceSet(context: NSObject) -> NSObject? {
		let selector = NSSelectorFromString("defaultDeviceSetWithError:")
		guard let implementation = context.method(for: selector) else {
			return nil
		}
		return unsafeBitCast(implementation, to: DeviceSetFunction.self)(context, selector, nil) as? NSObject
	}

	private static func developerDirectoryPath() -> String {
		let process = Process()
		let outputPipe = Pipe()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
		process.arguments = ["-p"]
		process.standardOutput = outputPipe
		try? process.run()
		process.waitUntilExit()
		let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
		return output.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
