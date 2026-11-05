import CoreGraphics

/// Where an element without an accessibility identifier sits: inside the nearest ancestor that has one, as the n-th
/// element of its type there (D-194). Replay taps it the same way (D-119), with no text and no coordinates.
struct TapFallback: Codable, Equatable {
	let containerIdentifier: String
	let elementType: String
	let index: Int
}

enum TapFallbackLocator {
	/// XCUITest element types for the Simulator's accessibility roles; nil for roles replay can't name by type.
	static let elementTypes = [
		"AXButton": "button",
		"AXStaticText": "staticText",
		"AXImage": "image",
		"AXCell": "cell",
		"AXTextField": "textField",
		"AXSecureTextField": "secureTextField",
		"AXLink": "link",
		"AXCheckBox": "switch",
		"AXSwitch": "switch",
		"AXTextArea": "textView",
	]

	static func fallback(for hit: SimulatorHit, in elements: [SimulatorElement]) -> TapFallback? {
		guard hit.identifier.isEmpty,
			let elementType = elementTypes[hit.role],
			let target = elements.first(where: { $0.role == hit.role && isSameFrame($0.frame, hit.frame) })
		else {
			return nil
		}
		let byId = Dictionary(elements.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
		guard let container = nearestIdentifiedAncestor(of: target, byId: byId) else {
			return nil
		}
		let sameType = elements.filter { $0.role == hit.role && isDescendant($0, of: container, byId: byId) }
		guard let index = sameType.firstIndex(where: { $0.id == target.id }) else {
			return nil
		}
		return TapFallback(containerIdentifier: container.identifier, elementType: elementType, index: index)
	}

	private static func nearestIdentifiedAncestor(of element: SimulatorElement, byId: [Int: SimulatorElement]) -> SimulatorElement? {
		var parentId = element.parentId
		while let id = parentId,
			let parent = byId[id] {
			if !parent.identifier.isEmpty {
				return parent
			}
			parentId = parent.parentId
		}
		return nil
	}

	private static func isDescendant(_ element: SimulatorElement, of ancestor: SimulatorElement, byId: [Int: SimulatorElement]) -> Bool {
		var parentId = element.parentId
		while let id = parentId {
			if id == ancestor.id {
				return true
			}
			parentId = byId[id]?.parentId
		}
		return false
	}

	private static func isSameFrame(_ first: CGRect, _ second: CGRect) -> Bool {
		abs(first.minX - second.minX) < 1 && abs(first.minY - second.minY) < 1
			&& abs(first.width - second.width) < 1 && abs(first.height - second.height) < 1
	}
}
