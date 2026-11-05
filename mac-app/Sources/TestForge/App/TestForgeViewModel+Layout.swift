import Combine
import CoreGraphics
import SwiftUI

/// The narrowest the main window can be with the Tests panes now shown.
struct TestForgePanes: Equatable {
	let isTestListShown: Bool
	let isInspectorShown: Bool

	/// Hidden panes give their width back, so the window can shrink beside the Simulator in Split View (D-209).
	/// The sidebar is left out: its toolbar button never updates the column-visibility binding, and the split view
	/// already adds the sidebar's own width while it is shown (D-210).
	var windowMinWidth: CGFloat {
		var width = TestForgeConstants.Window.minWidth - TestForgeConstants.Window.sidebarMinWidth * 2
		if !isTestListShown {
			width -= TestForgeConstants.Tests.listMinWidth
		}
		if !isInspectorShown {
			width -= TestForgeConstants.Tests.inspectorMinWidth
		}
		return max(width, TestForgeConstants.Window.narrowestWidth)
	}
}

extension TestForgeViewModel {
	var windowMinWidthUpdates: AnyPublisher<CGFloat, Never> {
		Publishers.CombineLatest(testsViewModel.$isListPresented, testsViewModel.$isInspectorPresented)
			.map { isTestListShown, isInspectorShown in
				TestForgePanes(isTestListShown: isTestListShown, isInspectorShown: isInspectorShown).windowMinWidth
			}
			.removeDuplicates()
			.eraseToAnyPublisher()
	}
}
