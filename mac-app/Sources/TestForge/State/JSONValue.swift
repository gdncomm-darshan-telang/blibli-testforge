import Foundation

/// Untyped JSON for state slices; a section decodes the slice it owns into its own model on demand.
enum JSONValue: Codable, Equatable {
	case null
	case bool(Bool)
	case number(Double)
	case string(String)
	case array([JSONValue])
	case object([String: JSONValue])

	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		if container.decodeNil() {
			self = .null
		} else if let value = try? container.decode(Bool.self) {
			self = .bool(value)
		} else if let value = try? container.decode(Double.self) {
			self = .number(value)
		} else if let value = try? container.decode(String.self) {
			self = .string(value)
		} else if let value = try? container.decode([JSONValue].self) {
			self = .array(value)
		} else {
			let value = try container.decode([String: JSONValue].self)
			self = .object(value)
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		switch self {
			case .null:
				try container.encodeNil()
			case .bool(let value):
				try container.encode(value)
			case .number(let value):
				try container.encode(value)
			case .string(let value):
				try container.encode(value)
			case .array(let value):
				try container.encode(value)
			case .object(let value):
				try container.encode(value)
		}
	}

	/// Re-decodes this value as a typed model; nil when the shape doesn't match.
	func decoded<Model: Decodable>(as modelType: Model.Type) -> Model? {
		guard let data = try? JSONEncoder().encode(self) else {
			return nil
		}
		return try? JSONDecoder().decode(modelType, from: data)
	}
}
