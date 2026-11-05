import Foundation

/// The `queue` slice as the run queue reads it: every task, and who holds the simulator.
struct RunQueueSnapshot: Decodable {
	let tasks: [RunQueueTask]
	let deviceHolder: String?
	let waitingCount: Int

	private enum CodingKeys: String, CodingKey {
		case tasks
		case device
	}

	private enum DeviceKeys: String, CodingKey {
		case holder
		case waiting
	}

	private enum HolderKeys: String, CodingKey {
		case label
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		tasks = (try? container.decodeIfPresent([RunQueueTask].self, forKey: .tasks)) ?? []
		let device = try? container.nestedContainer(keyedBy: DeviceKeys.self, forKey: .device)
		let holder = try? device?.nestedContainer(keyedBy: HolderKeys.self, forKey: .holder)
		deviceHolder = try? holder?.decodeIfPresent(String.self, forKey: .label)
		let waiting = try? device?.decodeIfPresent([JSONValue].self, forKey: .waiting)
		waitingCount = waiting?.count ?? 0
	}
}

struct RunQueueTask: Decodable, Equatable, Identifiable {
	let id: String
	let title: String
	let status: String
	let lane: String
	let verdict: String?
	let error: String?
	let startedAt: Date?
	let endedAt: Date?

	private enum CodingKeys: String, CodingKey {
		case id
		case title
		case status
		case lane
		case verdict
		case error
		case startedAt
		case endedAt
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
		title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? ""
		status = (try? container.decodeIfPresent(String.self, forKey: .status)) ?? "done"
		lane = (try? container.decodeIfPresent(String.self, forKey: .lane)) ?? "general"
		verdict = try? container.decodeIfPresent(String.self, forKey: .verdict)
		error = try? container.decodeIfPresent(String.self, forKey: .error)
		startedAt = (try? container.decodeIfPresent(String.self, forKey: .startedAt)).flatMap { $0.flatMap { ServerDate.parse(text: $0) } }
		endedAt = (try? container.decodeIfPresent(String.self, forKey: .endedAt)).flatMap { $0.flatMap { ServerDate.parse(text: $0) } }
	}
}

enum RunQueueTaskAction: String {
	case moveUp
	case moveDown
	case cancel
	case retry

	var busyTitle: String {
		switch self {
			case .moveUp:
				return String(localized: "Moving up…")
			case .moveDown:
				return String(localized: "Moving down…")
			case .cancel:
				return String(localized: "Cancelling…")
			case .retry:
				return String(localized: "Retrying…")
		}
	}
}

/// D-213: the in-flight action and last failure of one queue row, drawn on that row.
struct RunQueueRowActionState: Equatable {
	let pendingAction: RunQueueTaskAction?
	let failure: String?
}

struct RunQueueRowModel: Equatable, Identifiable {
	let id: String
	let title: String
	let detail: String
	let statusSymbol: String
	let tone: VerdictTone
	let isRunning: Bool
	let canMoveUp: Bool
	let canMoveDown: Bool
	let canCancel: Bool
	let canRetry: Bool
}

struct RunQueueGroup: Equatable, Identifiable {
	let id: String
	let title: String
	let rows: [RunQueueRowModel]
}

struct RunQueueContent: Equatable {
	let deviceText: String
	let groups: [RunQueueGroup]
	let hasFinished: Bool
}
