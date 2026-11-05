import AppKit

@MainActor
protocol DockBadging {
	/// Nil or zero clears the badge.
	func show(count: Int?)
}

struct ApplicationDockBadge: DockBadging {
	private let dockTile: NSDockTile

	init(dockTile: NSDockTile) {
		self.dockTile = dockTile
	}

	func show(count: Int?) {
		guard let count,
			count > 0
		else {
			dockTile.badgeLabel = nil
			return
		}
		dockTile.badgeLabel = "\(count)"
	}
}
