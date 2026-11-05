import CoreGraphics
import Foundation

/// D-164 `timeline.json`, written by the server beside a demo's raw recording.
struct DemoTimeline: Decodable {
	let caseId: String
	let macroName: String
	let screen: CGSize
	let verdict: String
	let notes: DemoNotes?
	let mocks: [DemoMock]
	let events: [DemoEvent]
	let videoFileName: String?

	var isPassed: Bool {
		verdict.hasPrefix("PASS")
	}

	private enum CodingKeys: String, CodingKey {
		case caseId
		case macroName
		case screen
		case verdict
		case notes
		case mocks
		case events
		case videoFileName = "video"
	}

	private enum ScreenKeys: String, CodingKey {
		case width
		case height
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		caseId = (try? container.decodeIfPresent(String.self, forKey: .caseId)) ?? ""
		macroName = (try? container.decodeIfPresent(String.self, forKey: .macroName)) ?? ""
		let screenContainer = try? container.nestedContainer(keyedBy: ScreenKeys.self, forKey: .screen)
		let width = (try? screenContainer?.decodeIfPresent(Double.self, forKey: .width)) ?? 0
		let height = (try? screenContainer?.decodeIfPresent(Double.self, forKey: .height)) ?? 0
		screen = CGSize(width: width, height: height)
		verdict = (try? container.decodeIfPresent(String.self, forKey: .verdict)) ?? ""
		notes = try? container.decodeIfPresent(DemoNotes.self, forKey: .notes)
		mocks = (try? container.decodeIfPresent([DemoMock].self, forKey: .mocks)) ?? []
		events = (try? container.decodeIfPresent([DemoEvent].self, forKey: .events)) ?? []
		videoFileName = try? container.decodeIfPresent(String.self, forKey: .videoFileName)
	}
}

/// One text in both demo languages.
struct DemoText: Decodable, Equatable {
	let english: String
	let bahasa: String

	private enum CodingKeys: String, CodingKey {
		case english = "en"
		case bahasa = "id"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		english = (try? container.decodeIfPresent(String.self, forKey: .english)) ?? ""
		bahasa = (try? container.decodeIfPresent(String.self, forKey: .bahasa)) ?? ""
	}

	func text(in language: DemoLanguage) -> String {
		switch language {
			case .english:
				return english
			case .bahasa:
				return bahasa.isEmpty ? english : bahasa
		}
	}
}

struct DemoNotes: Decodable {
	let title: DemoText?
	let checks: DemoText?
	let why: DemoText?
	let setup: DemoText?
	let steps: [String: DemoText]

	private enum CodingKeys: String, CodingKey {
		case title
		case checks
		case why
		case setup
		case steps
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		title = try? container.decodeIfPresent(DemoText.self, forKey: .title)
		checks = try? container.decodeIfPresent(DemoText.self, forKey: .checks)
		why = try? container.decodeIfPresent(DemoText.self, forKey: .why)
		setup = try? container.decodeIfPresent(DemoText.self, forKey: .setup)
		steps = (try? container.decodeIfPresent([String: DemoText].self, forKey: .steps)) ?? [:]
	}
}

struct DemoMock: Decodable {
	let endpoint: String
	let variant: String
	let note: DemoText?

	private enum CodingKeys: String, CodingKey {
		case endpoint
		case variant
		case note
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		endpoint = (try? container.decodeIfPresent(String.self, forKey: .endpoint)) ?? ""
		variant = (try? container.decodeIfPresent(String.self, forKey: .variant)) ?? ""
		note = try? container.decodeIfPresent(DemoText.self, forKey: .note)
	}
}

/// One replayed step: milliseconds since the recording started; `frame` in device points where to look.
struct DemoEvent: Decodable {
	let stepId: String?
	let kind: String
	let text: String
	let routine: String?
	let startMs: Double
	let endMs: Double
	let holdUntilMs: Double?
	let isPassed: Bool
	let isSkipped: Bool
	let frame: CGRect?

	static let checkKinds: Set<String> = ["assert", "waitFor", "waitForGone", "assertRequested"]

	var isCheck: Bool {
		Self.checkKinds.contains(kind)
	}

	private enum CodingKeys: String, CodingKey {
		case stepId = "id"
		case kind = "do"
		case text
		case routine = "from"
		case startMs
		case endMs
		case holdUntilMs
		case isPassed = "ok"
		case isSkipped = "skipped"
		case frame
	}

	private enum FrameKeys: String, CodingKey {
		case xPosition = "x"
		case yPosition = "y"
		case width
		case height
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		stepId = try? container.decodeIfPresent(String.self, forKey: .stepId)
		kind = (try? container.decodeIfPresent(String.self, forKey: .kind)) ?? ""
		text = (try? container.decodeIfPresent(String.self, forKey: .text)) ?? ""
		routine = try? container.decodeIfPresent(String.self, forKey: .routine)
		startMs = (try? container.decodeIfPresent(Double.self, forKey: .startMs)) ?? 0
		endMs = (try? container.decodeIfPresent(Double.self, forKey: .endMs)) ?? startMs
		holdUntilMs = try? container.decodeIfPresent(Double.self, forKey: .holdUntilMs)
		isPassed = (try? container.decodeIfPresent(Bool.self, forKey: .isPassed)) ?? false
		isSkipped = (try? container.decodeIfPresent(Bool.self, forKey: .isSkipped)) ?? false
		let frameContainer = try? container.nestedContainer(keyedBy: FrameKeys.self, forKey: .frame)
		if let frameContainer,
			let xPosition = try? frameContainer.decode(Double.self, forKey: .xPosition),
			let yPosition = try? frameContainer.decode(Double.self, forKey: .yPosition),
			let width = try? frameContainer.decode(Double.self, forKey: .width),
			let height = try? frameContainer.decode(Double.self, forKey: .height) {
			frame = CGRect(x: xPosition, y: yPosition, width: width, height: height)
		} else {
			frame = nil
		}
	}
}

enum DemoLanguage: String, CaseIterable, Identifiable {
	case english = "en"
	case bahasa = "id"

	var id: String {
		rawValue
	}

	/// Each language in its own words, so either reader finds theirs.
	var title: String {
		switch self {
			case .english:
				return "English"
			case .bahasa:
				return "Bahasa Indonesia"
		}
	}
}
