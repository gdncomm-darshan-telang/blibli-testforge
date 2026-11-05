import Foundation

/// The server's `remoteControl` slice (D-150): the `claude remote-control` server the TestForge supervises.
struct RemoteControlState: Decodable, Equatable {
	let isRunning: Bool
	let name: String
	let phase: String
	let spawnMode: String
	let capacityUsed: Int?
	let capacityMax: Int?
	let sessionURLs: [URL]
	let environmentURL: URL?
	let problem: String?
	let output: [String]

	private enum CodingKeys: String, CodingKey {
		case isRunning
		case name
		case phase
		case spawnMode
		case capacity
		case sessionUrls
		case environmentUrl
		case problem
		case output
	}

	private struct Capacity: Decodable {
		let used: Int
		let max: Int
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		isRunning = (try? container.decodeIfPresent(Bool.self, forKey: .isRunning)) ?? false
		name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? "TestForge"
		phase = (try? container.decodeIfPresent(String.self, forKey: .phase)) ?? "stopped"
		spawnMode = (try? container.decodeIfPresent(String.self, forKey: .spawnMode)) ?? "same-dir"
		let capacity = try? container.decodeIfPresent(Capacity.self, forKey: .capacity)
		capacityUsed = capacity?.used
		capacityMax = capacity?.max
		let sessionTexts = (try? container.decodeIfPresent([String].self, forKey: .sessionUrls)) ?? []
		sessionURLs = sessionTexts.compactMap(URL.init(string:))
		let environmentText = try? container.decodeIfPresent(String.self, forKey: .environmentUrl)
		environmentURL = environmentText.flatMap(URL.init(string:))
		problem = try? container.decodeIfPresent(String.self, forKey: .problem)
		output = (try? container.decodeIfPresent([String].self, forKey: .output)) ?? []
	}
}

enum RemoteControlSpawnMode: String, CaseIterable, Identifiable {
	case sameDirectory = "same-dir"
	case worktree

	var id: String { rawValue }

	var title: String {
		switch self {
			case .sameDirectory:
				return String(localized: "Same folder")
			case .worktree:
				return String(localized: "Own worktree per session")
		}
	}
}

/// What the Remote Control panel shows, ready to render.
struct RemoteControlDisplay: Equatable {
	enum Status: Equatable {
		case off
		case starting
		case connected
		case problem
	}

	let status: Status
	let title: String
	let detail: String
	let openURL: URL?
	let problem: String?
	let output: [String]
}
