import Foundation

struct GitChangedFile: Decodable, Equatable, Identifiable {
	let path: String
	let state: String

	var id: String { path }

	private enum CodingKeys: String, CodingKey {
		case path
		case state
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		path = (try? container.decodeIfPresent(String.self, forKey: .path)) ?? ""
		state = (try? container.decodeIfPresent(String.self, forKey: .state)) ?? ""
	}
}

/// `git status` of the developer's working repo as `/api/git/*` reports it (D-200).
struct GitRepoStatus: Decodable, Equatable {
	/// Nil while HEAD is detached.
	let branch: String?

	let sha: String?
	let subject: String
	let upstream: String?
	let ahead: Int
	let behind: Int
	let changedCount: Int
	let files: [GitChangedFile]
	let isDirty: Bool
	let fetchedAt: Date?
	let stashCount: Int

	/// A merge, rebase, cherry-pick or revert left half done; the server refuses every write until it's finished.
	let operation: String?

	let note: String?
	let stashed: String?

	private enum CodingKeys: String, CodingKey {
		case branch
		case sha
		case subject
		case upstream
		case ahead
		case behind
		case changedCount
		case files
		case isDirty
		case fetchedAt
		case stashCount
		case operation
		case note
		case stashed
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		branch = try? container.decodeIfPresent(String.self, forKey: .branch)
		sha = try? container.decodeIfPresent(String.self, forKey: .sha)
		subject = (try? container.decodeIfPresent(String.self, forKey: .subject)) ?? ""
		upstream = try? container.decodeIfPresent(String.self, forKey: .upstream)
		ahead = (try? container.decodeIfPresent(Int.self, forKey: .ahead)) ?? 0
		behind = (try? container.decodeIfPresent(Int.self, forKey: .behind)) ?? 0
		changedCount = (try? container.decodeIfPresent(Int.self, forKey: .changedCount)) ?? 0
		files = (try? container.decodeIfPresent([GitChangedFile].self, forKey: .files)) ?? []
		isDirty = (try? container.decodeIfPresent(Bool.self, forKey: .isDirty)) ?? false
		let fetchedText = try? container.decodeIfPresent(String.self, forKey: .fetchedAt)
		fetchedAt = fetchedText.flatMap { ServerDate.parse(text: $0) }
		stashCount = (try? container.decodeIfPresent(Int.self, forKey: .stashCount)) ?? 0
		operation = try? container.decodeIfPresent(String.self, forKey: .operation)
		note = try? container.decodeIfPresent(String.self, forKey: .note)
		stashed = try? container.decodeIfPresent(String.self, forKey: .stashed)
	}
}

struct GitStatusEnvelope: Decodable {
	let status: GitRepoStatus

	private enum CodingKeys: String, CodingKey {
		case status
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		status = try container.decode(GitRepoStatus.self, forKey: .status)
	}
}

enum GitControlPhase: Equatable {
	case loading
	case loaded
	case failed(message: String)
}

enum GitAction: Equatable {
	case fetch
	case fastForward
	case switchBranch(String)
	case restoreStash

	var progressText: String {
		switch self {
			case .fetch:
				return String(localized: "Fetching from GitHub…")
			case .fastForward:
				return String(localized: "Updating the branch…")
			case .switchBranch(let branch):
				return String(localized: "Switching to \(branch)…")
			case .restoreStash:
				return String(localized: "Restoring your stashed changes…")
		}
	}
}

/// A switch waiting for the person to agree to stash their uncommitted changes first.
struct GitSwitchRequest: Identifiable, Equatable {
	let branch: String
	let changedCount: Int

	var id: String { branch }
}

struct GitMessage: Equatable {
	let text: String
	let isError: Bool
}

/// What the status card shows, already worded.
struct GitStatusContent: Equatable {
	let title: String
	let subject: String
	let syncText: String
	let changesText: String
	let fetchedText: String
	let warning: String?
	let files: [GitChangedFile]
	let isBehind: Bool
	let hasStash: Bool
}
