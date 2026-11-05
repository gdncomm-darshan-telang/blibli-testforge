import Foundation

protocol MacroRecording {
	/// Writes the macro into the repo's UI test folder and links it to the test cases; never overwrites another macro.
	func saveRecorded(request: RecordedMacroRequest) async throws -> RecordedMacroResponse

	/// Macros recorded in Scan, newest first (D-174).
	func listRecorded() async throws -> [RecordedMacroSummary]

	/// Driver-only replay; never sends a failure to Claude.
	func replay(macroId: String) async throws

	func steps(macroId: String) async throws -> MacroStepList

	/// Writes reordered, removed and edited steps back to the macro's own file (D-195).
	func saveSteps(macroId: String, body: [String: JSONValue]) async throws

	func inputs(macroId: String) async throws -> CaseInputs
}

struct RecordedMacroRequest {
	let name: String
	let caseIds: [String]
	let module: String
	let submodule: String
	let isFreshStart: Bool
	let steps: [RecordedStep]
}

struct RecordedMacroResponse: Decodable, Equatable {
	struct Warning: Decodable, Equatable {
		let text: String

		private enum CodingKeys: String, CodingKey {
			case text
		}

		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			text = (try? container.decodeIfPresent(String.self, forKey: .text)) ?? ""
		}
	}

	struct SavedMacro: Decodable, Equatable {
		let id: String
		let name: String

		private enum CodingKeys: String, CodingKey {
			case id
			case name
		}

		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? ""
			name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
		}
	}

	let macro: SavedMacro?
	let path: String
	let warnings: [Warning]

	private enum CodingKeys: String, CodingKey {
		case macro
		case path
		case warnings
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		macro = try? container.decodeIfPresent(SavedMacro.self, forKey: .macro)
		path = (try? container.decodeIfPresent(String.self, forKey: .path)) ?? ""
		warnings = (try? container.decodeIfPresent([Warning].self, forKey: .warnings)) ?? []
	}
}

/// `POST /api/macros/v2/recorded` (D-171); `GET` lists them (D-174).
struct MacroRecordingService: MacroRecording {
	private let client: DashboardClient

	init(client: DashboardClient) {
		self.client = client
	}

	func saveRecorded(request: RecordedMacroRequest) async throws -> RecordedMacroResponse {
		let gestures = request.steps.map { step -> JSONValue in
			var fields: [String: JSONValue] = [
				"gesture": .string(step.action.gesture.rawValue),
				"identifier": .string(step.action.identifier),
				"label": .string(step.action.label),
				"screenName": .string(step.screenName),
			]
			if let fallback = step.action.fallback {
				fields["containerIdentifier"] = .string(fallback.containerIdentifier)
				fields["elementType"] = .string(fallback.elementType)
				fields["index"] = .number(Double(fallback.index))
			}
			if let anchorIdentifier = step.anchorIdentifier {
				fields["anchorIdentifier"] = .string(anchorIdentifier)
			}
			if let nextScreenName = step.nextScreenName {
				fields["nextScreenName"] = .string(nextScreenName)
			}
			return .object(fields)
		}
		let body: [String: JSONValue] = [
			"name": .string(request.name),
			"caseIds": .array(request.caseIds.map(JSONValue.string)),
			"module": .string(request.module),
			"submodule": .string(request.submodule),
			"startFresh": .bool(request.isFreshStart),
			"gestures": .array(gestures),
		]
		let data = try await client.post(path: "api/macros/v2/recorded", json: body)
		return try JSONDecoder().decode(RecordedMacroResponse.self, from: data)
	}

	func listRecorded() async throws -> [RecordedMacroSummary] {
		let data = try await client.get(path: "api/macros/v2/recorded")
		return try JSONDecoder().decode(RecordedMacroList.self, from: data).macros
	}

	func replay(macroId: String) async throws {
		try await client.post(path: "api/macros/v2/\(macroId)/replay")
	}

	func steps(macroId: String) async throws -> MacroStepList {
		let data = try await client.get(path: "api/macros/v2/\(macroId)/steps")
		return try JSONDecoder().decode(MacroStepList.self, from: data)
	}

	func saveSteps(macroId: String, body: [String: JSONValue]) async throws {
		_ = try await client.put(path: "api/macros/v2/\(macroId)/steps", json: body)
	}

	func inputs(macroId: String) async throws -> CaseInputs {
		let data = try await client.get(path: "api/macros/v2/\(macroId)/inputs")
		return try JSONDecoder().decode(CaseInputs.self, from: data)
	}
}
