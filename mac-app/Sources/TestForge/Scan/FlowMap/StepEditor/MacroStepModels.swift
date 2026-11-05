import Foundation

/// `GET /api/macros/v2/:id/steps` (D-195): a saved macro's own steps and what each may change.
struct MacroStepList: Decodable, Equatable {
	let steps: [MacroStep]

	private enum CodingKeys: String, CodingKey {
		case steps
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		steps = (try? container.decodeIfPresent([MacroStep].self, forKey: .steps)) ?? []
	}
}

struct MacroStep: Decodable, Equatable, Identifiable {
	let id: String
	let kind: String
	let text: String
	let fields: [String]
	var timeout: Double?
	var isOptional: Bool
	var typedText: String?
	var seconds: Double?
	var name: String?

	var canChangeTimeout: Bool { fields.contains(MacroStepField.timeout) }
	var canChangeOptional: Bool { fields.contains(MacroStepField.optional) }
	var canChangeText: Bool { fields.contains(MacroStepField.text) }
	var canChangeSeconds: Bool { fields.contains(MacroStepField.seconds) }
	var canChangeName: Bool { fields.contains(MacroStepField.name) }

	private enum CodingKeys: String, CodingKey {
		case id
		case kind
		case text
		case fields
		case timeout
		case isOptional
		case typedText
		case seconds
		case name
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
		kind = (try? container.decodeIfPresent(String.self, forKey: .kind)) ?? ""
		text = (try? container.decodeIfPresent(String.self, forKey: .text)) ?? ""
		fields = (try? container.decodeIfPresent([String].self, forKey: .fields)) ?? []
		timeout = try? container.decodeIfPresent(Double.self, forKey: .timeout)
		isOptional = (try? container.decodeIfPresent(Bool.self, forKey: .isOptional)) ?? false
		typedText = try? container.decodeIfPresent(String.self, forKey: .typedText)
		seconds = try? container.decodeIfPresent(Double.self, forKey: .seconds)
		name = try? container.decodeIfPresent(String.self, forKey: .name)
	}
}

/// The server's names for a step's editable fields.
enum MacroStepField {
	static let timeout = "timeout"
	static let optional = "optional"
	static let text = "text"
	static let seconds = "seconds"
	static let name = "name"
}

enum MacroStepEditorState: Equatable {
	case hidden
	case loading
	case editing
	case saving
	case failed(message: String)
}
