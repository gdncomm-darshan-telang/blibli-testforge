import Foundation

/// `GET /api/prerequisites` (D-190): tools, the Claude Code plugin and MCP servers this Mac needs.
struct PrerequisitesReport: Decodable, Equatable {
	let items: [PrerequisiteItem]
	let checkedAt: Date?

	private enum CodingKeys: String, CodingKey {
		case items
		case checkedAt
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		items = (try? container.decodeIfPresent([PrerequisiteItem].self, forKey: .items)) ?? []
		let checkedText = try? container.decodeIfPresent(String.self, forKey: .checkedAt)
		checkedAt = checkedText.flatMap { ServerDate.parse(text: $0) }
	}
}

struct PrerequisiteItem: Decodable, Equatable, Identifiable {
	let id: String
	let label: String
	/// `tool`, `plugin` or `mcp`.
	let kind: String
	let isOk: Bool
	let isRequired: Bool
	let detail: String
	let howTo: String

	private enum CodingKeys: String, CodingKey {
		case id
		case label
		case kind
		case isOk = "ok"
		case isRequired
		case detail
		case howTo
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
		label = (try? container.decodeIfPresent(String.self, forKey: .label)) ?? ""
		kind = (try? container.decodeIfPresent(String.self, forKey: .kind)) ?? "tool"
		isOk = (try? container.decodeIfPresent(Bool.self, forKey: .isOk)) ?? false
		isRequired = (try? container.decodeIfPresent(Bool.self, forKey: .isRequired)) ?? false
		detail = (try? container.decodeIfPresent(String.self, forKey: .detail)) ?? ""
		howTo = (try? container.decodeIfPresent(String.self, forKey: .howTo)) ?? ""
	}
}

struct PrerequisiteRowModel: Equatable, Identifiable {
	let id: String
	let label: String
	let groupTitle: String
	let detail: String
	let statusSymbol: String
	let tone: VerdictTone
	/// The command or step that fixes it; nil when nothing needs doing.
	let howTo: String?
}

enum PrerequisitesState: Equatable {
	case loading
	case loaded([PrerequisiteRowModel], checkedText: String)
	case failed(message: String)
}
