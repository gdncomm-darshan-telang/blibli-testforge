import Foundation

/// Why an update can't be applied to this checkout right now.
enum UpdateBlock: Equatable {
	case notOnTrunk(branch: String)
	case localChanges
	case diverged
}

struct UpdateStatus: Equatable {
	enum State: Equatable {
		case upToDate
		case available(count: Int)
		case blocked(UpdateBlock)
	}

	let state: State
	let currentCommit: String
	let latestCommit: String

	/// Subjects of the newest incoming commits, newest first.
	let incoming: [String]
}

enum UpdatePhase: Equatable {
	case pulling
	case building
}

enum UpdateError: LocalizedError {
	case noCheckout
	case notUpdatable
	case fetchFailed(String)
	case pullFailed(String)
	case buildFailed(String)
	case builtAppMissing

	var errorDescription: String? {
		switch self {
			case .noCheckout:
				return String(localized: "No TestForge checkout is chosen yet. Finish Setup first.")
			case .notUpdatable:
				return String(localized: "There is nothing to update right now.")
			case .fetchFailed(let message):
				return String(localized: "Couldn't reach GitHub: \(message)")
			case .pullFailed(let message):
				return String(localized: "Couldn't pull the latest master: \(message)")
			case .buildFailed(let message):
				return String(localized: "The new code was pulled but the build failed, so this copy keeps running: \(message)")
			case .builtAppMissing:
				return String(localized: "The build finished but TestForge.app is missing from mac-app/build.")
		}
	}
}
