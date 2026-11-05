import Foundation

/// One macro recorded in Scan, as the saved-macros list shows it (D-174).
struct RecordedMacroSummary: Decodable, Equatable, Identifiable {
	let id: String
	let name: String
	let createdAt: Date?
	let testCases: [String]
	let path: String?
	let gestureCount: Int
	let foundByText: Int
	let needsPerson: Int
	let startsFresh: Bool

	private enum CodingKeys: String, CodingKey {
		case id
		case name
		case createdAt
		case testCases
		case path
		case gestureCount
		case foundByText
		case needsPerson
		case startsFresh
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(String.self, forKey: .id)
		name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? id
		let createdText = try? container.decodeIfPresent(String.self, forKey: .createdAt)
		createdAt = createdText.flatMap { try? Date($0, strategy: .iso8601) }
		testCases = (try? container.decodeIfPresent([String].self, forKey: .testCases)) ?? []
		path = try? container.decodeIfPresent(String.self, forKey: .path)
		gestureCount = (try? container.decodeIfPresent(Int.self, forKey: .gestureCount)) ?? 0
		foundByText = (try? container.decodeIfPresent(Int.self, forKey: .foundByText)) ?? 0
		needsPerson = (try? container.decodeIfPresent(Int.self, forKey: .needsPerson)) ?? 0
		startsFresh = (try? container.decodeIfPresent(Bool.self, forKey: .startsFresh)) ?? false
	}

	/// Every tap found by its accessibility ID; nothing falls back to text or a person.
	var isFullyIdentified: Bool {
		foundByText == 0 && needsPerson == 0
	}
}

struct RecordedMacroList: Decodable {
	let macros: [RecordedMacroSummary]

	private enum CodingKeys: String, CodingKey {
		case macros
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		macros = (try? container.decodeIfPresent([RecordedMacroSummary].self, forKey: .macros)) ?? []
	}
}
