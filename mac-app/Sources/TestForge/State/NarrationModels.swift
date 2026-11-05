import CoreGraphics
import Foundation

/// The `narration` slice: each run's steps in plain words, keyed by its job id.
struct NarrationState: Decodable, Equatable {
	let runs: [NarratedRun]

	private enum CodingKeys: String, CodingKey {
		case runs
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		runs = (try? container.decodeIfPresent([NarratedRun].self, forKey: .runs)) ?? []
	}
}

struct NarratedRun: Decodable, Equatable, Identifiable {
	/// The job id; cancelling the run cancels this job.
	let id: String

	let caseId: String?
	let title: String
	let startedAt: Date?
	let endedAt: Date?
	let verdict: String?
	let steps: [NarratedStep]

	/// The device size the step frames were read on; present once a frame was read for the step outline.
	let screen: DeviceScreen?

	/// The Claude session behind a first run or triage (D-147); nil for a replay.
	let sessionId: String?

	/// A Claude run's current model alias (`haiku`, `sonnet`, `opus`) and why (D-158); nil for a replay.
	let model: String?

	let modelReason: String?

	/// Present on an explained replay or demo (D-165): what the live overlay over the Simulator shows.
	let explain: NarratedExplain?

	/// What the phone is busy with while nothing on screen is worth watching (setup, a relaunch, loading); nil otherwise.
	let busy: NarratedBusy?

	var isRunning: Bool {
		endedAt == nil
	}

	private enum CodingKeys: String, CodingKey {
		case id = "key"
		case caseId
		case title
		case startedAt
		case endedAt
		case verdict
		case steps
		case screen
		case sessionId
		case model
		case modelReason
		case explain
		case busy
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
		caseId = try? container.decodeIfPresent(String.self, forKey: .caseId)
		title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? ""
		let startedText = try? container.decodeIfPresent(String.self, forKey: .startedAt)
		startedAt = startedText.flatMap { ServerDate.parse(text: $0) }
		let endedText = try? container.decodeIfPresent(String.self, forKey: .endedAt)
		endedAt = endedText.flatMap { ServerDate.parse(text: $0) }
		verdict = try? container.decodeIfPresent(String.self, forKey: .verdict)
		steps = (try? container.decodeIfPresent([NarratedStep].self, forKey: .steps)) ?? []
		screen = try? container.decodeIfPresent(DeviceScreen.self, forKey: .screen)
		sessionId = try? container.decodeIfPresent(String.self, forKey: .sessionId)
		model = try? container.decodeIfPresent(String.self, forKey: .model)
		modelReason = try? container.decodeIfPresent(String.self, forKey: .modelReason)
		explain = try? container.decodeIfPresent(NarratedExplain.self, forKey: .explain)
		busy = try? container.decodeIfPresent(NarratedBusy.self, forKey: .busy)
	}
}

struct NarratedBusy: Decodable, Equatable {
	let message: String
	let since: Date?

	private enum CodingKeys: String, CodingKey {
		case message
		case since
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		message = (try? container.decodeIfPresent(String.self, forKey: .message)) ?? ""
		let sinceText = try? container.decodeIfPresent(String.self, forKey: .since)
		since = sinceText.flatMap { ServerDate.parse(text: $0) }
	}
}

enum NarratedExplainPhase: String, Equatable {
	case intro
	case steps
	case result
}

/// The macro's plain-words notes and where to look now; every text is in English and Bahasa Indonesia.
struct NarratedExplain: Decodable, Equatable {
	let phase: NarratedExplainPhase
	let title: DemoText?
	let checks: DemoText?
	let why: DemoText?
	let setup: DemoText?
	let focus: NarratedFocus?

	private enum CodingKeys: String, CodingKey {
		case phase
		case title
		case checks
		case why
		case setup
		case focus
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let phaseText = try? container.decodeIfPresent(String.self, forKey: .phase)
		phase = phaseText.flatMap { NarratedExplainPhase(rawValue: $0) } ?? .intro
		title = try? container.decodeIfPresent(DemoText.self, forKey: .title)
		checks = try? container.decodeIfPresent(DemoText.self, forKey: .checks)
		why = try? container.decodeIfPresent(DemoText.self, forKey: .why)
		setup = try? container.decodeIfPresent(DemoText.self, forKey: .setup)
		focus = try? container.decodeIfPresent(NarratedFocus.self, forKey: .focus)
	}
}

enum NarratedFocusStyle: String, Equatable {
	case action
	case checking
	case step
	case passed
	case failed
}

struct NarratedFocus: Decodable, Equatable {
	let style: NarratedFocusStyle
	let note: DemoText?

	/// The robot's own words, shown when the macro has no notes at all.
	let text: String

	/// A shared setup routine's step (relaunch, log in): the overlay stays quiet for it.
	let isRoutine: Bool

	/// In device points.
	let frame: CGRect?

	private enum CodingKeys: String, CodingKey {
		case style
		case note
		case text
		case isRoutine
		case frame
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let styleText = try? container.decodeIfPresent(String.self, forKey: .style)
		style = styleText.flatMap { NarratedFocusStyle(rawValue: $0) } ?? .step
		note = try? container.decodeIfPresent(DemoText.self, forKey: .note)
		text = (try? container.decodeIfPresent(String.self, forKey: .text)) ?? ""
		isRoutine = (try? container.decodeIfPresent(Bool.self, forKey: .isRoutine)) ?? false
		let deviceRect = try? container.decodeIfPresent(DeviceRect.self, forKey: .frame)
		frame = deviceRect?.rect
	}
}

struct NarratedStep: Decodable, Equatable, Identifiable {
	let id: Int
	let text: String
	/// `working`, `done`, `failed`, `skipped` or `cancelled`.
	let status: String

	let durationMs: Double?
	let reason: String?
	let isCleanup: Bool
	let target: String?

	/// In device points; the server reads it only while the step outline is on.
	let frame: CGRect?

	private enum CodingKeys: String, CodingKey {
		case id = "n"
		case text
		case status
		case durationMs = "ms"
		case reason
		case isCleanup
		case target
		case frame
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(Int.self, forKey: .id)) ?? 0
		text = (try? container.decodeIfPresent(String.self, forKey: .text)) ?? ""
		status = (try? container.decodeIfPresent(String.self, forKey: .status)) ?? "working"
		durationMs = try? container.decodeIfPresent(Double.self, forKey: .durationMs)
		reason = try? container.decodeIfPresent(String.self, forKey: .reason)
		isCleanup = (try? container.decodeIfPresent(Bool.self, forKey: .isCleanup)) ?? false
		target = try? container.decodeIfPresent(String.self, forKey: .target)
		let deviceRect = try? container.decodeIfPresent(DeviceRect.self, forKey: .frame)
		frame = deviceRect?.rect
	}
}

struct DeviceRect: Decodable, Equatable {
	let rect: CGRect

	private enum CodingKeys: String, CodingKey {
		case originX = "x"
		case originY = "y"
		case width
		case height
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let originX = try container.decode(Double.self, forKey: .originX)
		let originY = try container.decode(Double.self, forKey: .originY)
		let width = try container.decode(Double.self, forKey: .width)
		let height = try container.decode(Double.self, forKey: .height)
		rect = CGRect(x: originX, y: originY, width: width, height: height)
	}
}
