import AppKit
import SwiftUI

/// ⌥ + scroll zooms the Measure canvas (D-144); a plain scroll still pans it. Only the Measure window's events are taken.
struct OptionScrollZoomModifier: ViewModifier {
	@Binding var zoom: CGFloat
	@State private var monitor: Any?

	func body(content: Content) -> some View {
		content
			.onAppear(perform: install)
			.onDisappear(perform: remove)
	}

	private func install() {
		guard monitor == nil else {
			return
		}
		let zoomBinding = $zoom
		monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
			guard event.modifierFlags.contains(.option),
				event.window?.identifier?.rawValue.hasPrefix(TestForgeConstants.Window.measureWindowId) ?? false
			else {
				return event
			}
			zoomBinding.wrappedValue = Self.zoom(zoomBinding.wrappedValue, scrolledBy: event)
			return nil
		}
	}

	private func remove() {
		guard let monitor else {
			return
		}
		NSEvent.removeMonitor(monitor)
		self.monitor = nil
	}

	/// Scrolling up zooms in. A trackpad reports many small deltas, a mouse wheel a few line-sized ones.
	private static func zoom(_ current: CGFloat, scrolledBy event: NSEvent) -> CGFloat {
		let rate = event.hasPreciseScrollingDeltas
			? TestForgeConstants.Measure.trackpadZoomRate
			: TestForgeConstants.Measure.wheelZoomRate
		let delta = event.scrollingDeltaY == 0 ? event.scrollingDeltaX : event.scrollingDeltaY
		let range = MeasureViewModel.zoomRange
		return min(max(current * exp(delta * rate), range.lowerBound), range.upperBound)
	}
}
