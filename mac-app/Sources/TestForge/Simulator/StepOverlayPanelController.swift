import AppKit
import SwiftUI

@MainActor
protocol StepOverlayPresenting: AnyObject {
	func show(content: StepOverlayContent, aboveWindowNumber windowNumber: Int)
	func hide()
}

/// A borderless, click-through panel ordered just above the Simulator window, so other apps still cover it.
@MainActor
final class StepOverlayPanelController: StepOverlayPresenting {
	private var panel: NSPanel?
	private var hostingView: NSHostingView<StepOverlayContentView>?

	/// Always ordered relative to the Simulator window, never to the front, so it can't float over other apps or Spaces.
	func show(content: StepOverlayContent, aboveWindowNumber windowNumber: Int) {
		let overlayPanel = panel ?? makePanel(content: content)
		let contentView = StepOverlayContentView(content: content)
		hostingView?.rootView = contentView
		if overlayPanel.frame != content.panelFrame {
			overlayPanel.setFrame(content.panelFrame, display: true)
		}
		overlayPanel.order(.above, relativeTo: windowNumber)
	}

	func hide() {
		panel?.orderOut(nil)
	}

	private func makePanel(content: StepOverlayContent) -> NSPanel {
		let overlayPanel = NSPanel(contentRect: content.panelFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
		overlayPanel.isOpaque = false
		overlayPanel.backgroundColor = .clear
		overlayPanel.hasShadow = false
		overlayPanel.ignoresMouseEvents = true
		overlayPanel.isReleasedWhenClosed = false
		overlayPanel.hidesOnDeactivate = false
		// On every Space: a panel tied to one Space makes macOS switch to it each time it is ordered (D-208),
		// e.g. once the Simulator is moved into Split View. It is only shown while the Simulator window is on screen.
		overlayPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
		let contentView = StepOverlayContentView(content: content)
		let host = NSHostingView(rootView: contentView)
		overlayPanel.contentView = host
		hostingView = host
		panel = overlayPanel
		return overlayPanel
	}
}
