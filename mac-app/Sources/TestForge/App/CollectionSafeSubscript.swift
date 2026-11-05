import Foundation

/// The iOS app's `[safe:]` subscript, which this package can't import.
extension Collection {
	subscript(safe index: Index) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}
