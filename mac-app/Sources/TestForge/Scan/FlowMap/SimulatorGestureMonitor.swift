import AppKit

/// A mouse press or release anywhere on screen, in Accessibility coordinates (top-left origin).
enum SimulatorPointerEvent: Equatable {
	case down(CGPoint)
	case up(CGPoint)
}

/// Watches the person's clicks while another app (the Simulator) is in front; needs the Accessibility permission.
protocol SimulatorGestureMonitoring: AnyObject {
	func start(handler: @escaping (SimulatorPointerEvent) -> Void)
	func stop()
}

final class GlobalPointerMonitor: SimulatorGestureMonitoring {
	private var monitor: Any?

	deinit {
		stop()
	}

	func start(handler: @escaping (SimulatorPointerEvent) -> Void) {
		stop()
		monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { event in
			let point = Self.accessibilityPoint(appKitPoint: NSEvent.mouseLocation)
			handler(event.type == .leftMouseDown ? .down(point) : .up(point))
		}
	}

	func stop() {
		if let monitor {
			NSEvent.removeMonitor(monitor)
		}
		monitor = nil
	}

	private static func accessibilityPoint(appKitPoint: CGPoint) -> CGPoint {
		let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
		return CGPoint(x: appKitPoint.x, y: primaryHeight - appKitPoint.y)
	}
}
