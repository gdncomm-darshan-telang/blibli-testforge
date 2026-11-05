import Foundation

/// `POST /api/batch/plan` (D-191): what a batch will do and what could stop it before it ends.
struct BatchPlan: Decodable, Equatable {
	let caseIds: [String]
	let replayCount: Int
	let claudeCount: Int
	let environmentSwitches: [BatchPlanSwitch]
	let logins: Int
	let stops: [BatchPlanStop]
	let isHandsFree: Bool

	private enum CodingKeys: String, CodingKey {
		case caseIds
		case replayCount
		case claudeCount
		case environmentSwitches
		case logins
		case stops
		case isHandsFree
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		caseIds = (try? container.decodeIfPresent([String].self, forKey: .caseIds)) ?? []
		replayCount = (try? container.decodeIfPresent(Int.self, forKey: .replayCount)) ?? 0
		claudeCount = (try? container.decodeIfPresent(Int.self, forKey: .claudeCount)) ?? 0
		environmentSwitches = (try? container.decodeIfPresent([BatchPlanSwitch].self, forKey: .environmentSwitches)) ?? []
		logins = (try? container.decodeIfPresent(Int.self, forKey: .logins)) ?? 0
		stops = (try? container.decodeIfPresent([BatchPlanStop].self, forKey: .stops)) ?? []
		isHandsFree = (try? container.decodeIfPresent(Bool.self, forKey: .isHandsFree)) ?? false
	}
}

struct BatchPlanSwitch: Decodable, Equatable {
	let label: String
	let beforeCase: String

	private enum CodingKeys: String, CodingKey {
		case label
		case beforeCase
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		label = (try? container.decodeIfPresent(String.self, forKey: .label)) ?? ""
		beforeCase = (try? container.decodeIfPresent(String.self, forKey: .beforeCase)) ?? ""
	}
}

struct BatchPlanStop: Decodable, Equatable, Identifiable {
	let id: String
	let text: String

	private enum CodingKeys: String, CodingKey {
		case id
		case text
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
		text = (try? container.decodeIfPresent(String.self, forKey: .text)) ?? ""
	}
}

struct BatchPlanSheetModel: Equatable {
	let title: String
	let lines: [String]
	let stops: [BatchPlanStop]
	let isHandsFree: Bool
	let caseIds: [String]
}

enum BatchPlanState: Equatable {
	case hidden
	case loading
	case ready(BatchPlanSheetModel)
	case failed(message: String)
}
