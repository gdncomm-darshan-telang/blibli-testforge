import Foundation

/// The `prompts` slice: what open runs wait on a person for (D-044).
struct RunPromptList: Decodable {
	let prompts: [RunPrompt]

	private enum CodingKeys: String, CodingKey {
		case prompts
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		prompts = (try? container.decodeIfPresent([RunPrompt].self, forKey: .prompts)) ?? []
	}
}

struct RunPrompt: Decodable, Equatable, Identifiable {
	enum Kind: String {
		/// Do something on the simulator the runner can't reach (a system popup), then say Done.
		case manual

		/// Type a value the run can't know, such as a production OTP.
		case input
	}

	let id: String
	let kind: Kind
	let title: String
	let text: String

	/// Hides what's typed, e.g. an OTP.
	let isSecret: Bool

	private enum CodingKeys: String, CodingKey {
		case id
		case kind
		case title
		case text
		case isSecret = "secret"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? ""
		let kindText = (try? container.decodeIfPresent(String.self, forKey: .kind)) ?? ""
		kind = Kind(rawValue: kindText) ?? .manual
		title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? ""
		text = (try? container.decodeIfPresent(String.self, forKey: .text)) ?? ""
		isSecret = (try? container.decodeIfPresent(Bool.self, forKey: .isSecret)) ?? false
	}
}

enum RunPromptAnswer: String {
	case done
	case skip
	case stop
}
