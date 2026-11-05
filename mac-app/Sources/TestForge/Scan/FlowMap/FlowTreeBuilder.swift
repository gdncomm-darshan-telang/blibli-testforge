import Foundation

/// A row in the flow tree: a screen reached from its parent by `viaText`, or a link back to a screen already shown.
struct FlowTreeNode: Equatable, Identifiable {
	let id: String
	let screenId: String
	let name: String
	let viaText: String?
	let isLink: Bool
	let children: [FlowTreeNode]?
}

/// Pure: the map as a tree from the start screen, breadth first, each screen placed once where it was first reached;
/// any other edge into it shows as a link row so no move is hidden.
enum FlowTreeBuilder {
	static func tree(map: FlowMap) -> [FlowTreeNode] {
		guard let startId = map.startScreenId ?? map.screens.first?.id else {
			return []
		}
		let parentEdges = firstReachingEdges(map: map, startId: startId)
		let unreached = map.screens.filter { $0.id != startId && parentEdges[$0.id] == nil }.map(\.id)
		return ([startId] + unreached).compactMap { node(screenId: $0, via: nil, map: map, parentEdges: parentEdges) }
	}

	static func actionText(action: FlowAction) -> String {
		let target = action.label.isEmpty ? action.identifier : action.label
		let name = target.isEmpty ? String(localized: "an unnamed \(roleName(role: action.role))") : "“\(target)”"
		switch action.gesture {
			case .tap:
				return String(localized: "tap \(name)")
			case .swipeUp:
				return String(localized: "swipe up on \(name)")
			case .swipeDown:
				return String(localized: "swipe down on \(name)")
			case .swipeLeft:
				return String(localized: "swipe left on \(name)")
			case .swipeRight:
				return String(localized: "swipe right on \(name)")
		}
	}

	/// For each screen, the edge that reached it first in a breadth-first walk from the start.
	private static func firstReachingEdges(map: FlowMap, startId: String) -> [String: FlowEdge] {
		var parentEdges: [String: FlowEdge] = [:]
		var visited: Set<String> = [startId]
		var queue = [startId]
		while !queue.isEmpty {
			let current = queue.removeFirst()
			for edge in map.edges where edge.fromScreenId == current && !visited.contains(edge.toScreenId) {
				visited.insert(edge.toScreenId)
				parentEdges[edge.toScreenId] = edge
				queue.append(edge.toScreenId)
			}
		}
		return parentEdges
	}

	private static func node(screenId: String, via edge: FlowEdge?, map: FlowMap, parentEdges: [String: FlowEdge]) -> FlowTreeNode? {
		guard let screen = map.screens.first(where: { $0.id == screenId }) else {
			return nil
		}
		let outgoing = map.edges.filter { $0.fromScreenId == screenId }
		let children = outgoing.compactMap { child -> FlowTreeNode? in
			if parentEdges[child.toScreenId]?.id == child.id {
				return node(screenId: child.toScreenId, via: child, map: map, parentEdges: parentEdges)
			}
			return link(edge: child, map: map)
		}
		return FlowTreeNode(
			id: edge.map { "\($0.id)>\(screenId)" } ?? screenId,
			screenId: screenId,
			name: screen.name,
			viaText: edge.map { actionText(action: $0.action) },
			isLink: false,
			children: children.isEmpty ? nil : children
		)
	}

	private static func link(edge: FlowEdge, map: FlowMap) -> FlowTreeNode? {
		guard let target = map.screens.first(where: { $0.id == edge.toScreenId }) else {
			return nil
		}
		return FlowTreeNode(
			id: "link:\(edge.id)",
			screenId: target.id,
			name: target.name,
			viaText: actionText(action: edge.action),
			isLink: true,
			children: nil
		)
	}

	private static func roleName(role: String) -> String {
		role.hasPrefix("AX") ? String(role.dropFirst(2)).lowercased() : role.lowercased()
	}
}
