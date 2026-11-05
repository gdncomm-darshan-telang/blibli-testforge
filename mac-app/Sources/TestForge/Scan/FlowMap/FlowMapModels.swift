import Foundation

/// One screen seen while recording: its fingerprint (normalized identifiers), the name shown and its thumbnail.
struct FlowScreen: Codable, Equatable, Identifiable {
	let id: String
	var name: String
	let title: String?
	var fingerprint: Set<String>
	var thumbnailFile: String?
	var visitCount: Int
	let firstSeenAt: Date
}

enum FlowGestureKind: String, Codable, Equatable {
	case tap
	case swipeUp
	case swipeDown
	case swipeLeft
	case swipeRight
}

/// What the person did on the Simulator: a gesture and the element it started on, read at mouse-down.
struct FlowAction: Codable, Equatable {
	let gesture: FlowGestureKind
	let identifier: String
	let label: String
	let role: String

	/// D-194: set for a tap on an element without an identifier — its container and position, so replay needs no person.
	var fallback: TapFallback?
}

/// A move from one screen to another, counted when the same action leads there again.
struct FlowEdge: Codable, Equatable, Identifiable {
	let id: String
	let fromScreenId: String
	let toScreenId: String
	let action: FlowAction
	var count: Int
}

/// One gesture in recording order, kept for Save as macro (D-171); the map above only keeps distinct moves.
struct RecordedStep: Codable, Equatable, Identifiable {
	let id: String
	let action: FlowAction
	let screenId: String
	let screenName: String

	/// An identifier that appeared on the screen this step led to; replay waits for it. Nil when the screen stayed.
	let anchorIdentifier: String?

	let nextScreenId: String?
	let nextScreenName: String?

	/// Replay finds a tap by its accessibility identifier; without one it falls back to the label, or a person.
	var isMissingIdentifier: Bool {
		action.gesture == .tap && action.identifier.isEmpty && action.fallback == nil
	}
}

struct FlowMap: Codable, Equatable {
	let createdAt: Date
	let deviceName: String
	var startScreenId: String?
	var screens: [FlowScreen]
	var edges: [FlowEdge]
	var gestureCount: Int

	/// Optional so maps saved before D-171 still open.
	var recordedSteps: [RecordedStep]?
}
