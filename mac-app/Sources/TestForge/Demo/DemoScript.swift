import CoreGraphics
import Foundation

enum DemoPointerStyle {
	case action
	case checking
	case passed
	case failed
}

struct DemoPointer {
	let rect: CGRect
	let style: DemoPointerStyle
	let badge: String?
}

/// A subtitle and, when the step has an element, where to point. Seconds on the rendered video's clock.
struct DemoCue {
	let start: Double
	let end: Double
	let text: String
	let pointer: DemoPointer?
}

struct DemoCardSection {
	let heading: String
	let body: String
}

struct DemoCard {
	let start: Double
	let end: Double
	let title: String
	let sections: [DemoCardSection]

	/// Set on the closing card only: it shows a check or cross and colors its title.
	var outcome: DemoOutcome? = nil
}

/// How the test ended, as the closing card shows it.
enum DemoOutcome: Equatable {
	case passed
	case failed
	case undecided

	init(verdict: String?) {
		let verdict = verdict ?? ""
		if verdict.hasPrefix("PASS") {
			self = .passed
		} else if verdict.hasPrefix("FAIL") {
			self = .failed
		} else {
			self = .undecided
		}
	}

	var symbolName: String {
		switch self {
			case .passed:
				return "checkmark.circle.fill"
			case .failed:
				return "xmark.circle.fill"
			case .undecided:
				return "exclamationmark.triangle.fill"
		}
	}
}

/// What one language's video shows and when: an opening card, subtitles with pointers, a closing card.
struct DemoScript {
	let language: DemoLanguage
	let intro: DemoCard
	let cues: [DemoCue]
	let outro: DemoCard
	let mainSeconds: Double

	/// Seconds cut from the start of the recording: the shared setup (home, relaunch) before the first explained step.
	let trimSeconds: Double

	static let introSeconds: Double = 6
	static let outroSeconds: Double = 4
	private static let minimumCueSeconds: Double = 2.5
	private static let leadInSeconds: Double = 1.5

	var totalSeconds: Double {
		Self.introSeconds + mainSeconds + Self.outroSeconds
	}

	init(timeline: DemoTimeline, language: DemoLanguage, recordingSeconds: Double) {
		self.language = language
		let explained = Self.explainedEvents(timeline: timeline, language: language)
		let firstStart = explained.first.map { $0.event.startMs / 1000 } ?? 0
		let trimSeconds = min(max(firstStart - Self.leadInSeconds, 0), max(recordingSeconds - 1, 0))
		self.trimSeconds = trimSeconds
		let mainSeconds = recordingSeconds - trimSeconds
		self.mainSeconds = mainSeconds
		let strings = DemoStrings(language: language)
		intro = Self.introCard(timeline: timeline, strings: strings)
		cues = Self.makeCues(explained: explained, strings: strings, offset: Self.introSeconds - trimSeconds, mainEnd: Self.introSeconds + mainSeconds)
		let outroStart = Self.introSeconds + mainSeconds
		outro = DemoCard(
			start: outroStart,
			end: outroStart + Self.outroSeconds,
			title: strings.resultTitle(DemoOutcome(verdict: timeline.verdict)),
			sections: [DemoCardSection(heading: strings.caseHeading(timeline.caseId), body: timeline.notes?.title?.text(in: language) ?? timeline.macroName)],
			outcome: DemoOutcome(verdict: timeline.verdict)
		)
	}

	private static func introCard(timeline: DemoTimeline, strings: DemoStrings) -> DemoCard {
		let language = strings.language
		var sections: [DemoCardSection] = []
		if let checks = timeline.notes?.checks?.text(in: language) {
			sections.append(DemoCardSection(heading: strings.checksHeading, body: checks))
		}
		if let why = timeline.notes?.why?.text(in: language) {
			sections.append(DemoCardSection(heading: strings.whyHeading, body: why))
		}
		let mockNotes = timeline.mocks.compactMap { $0.note?.text(in: language) }
		let setup = timeline.notes?.setup?.text(in: language) ?? mockNotes.first
		if let setup {
			sections.append(DemoCardSection(heading: strings.setupHeading, body: setup))
		}
		return DemoCard(start: 0, end: introSeconds, title: timeline.notes?.title?.text(in: language) ?? timeline.macroName, sections: sections)
	}

	/// Steps with a note are subtitled; without notes, each top-level check and action shows the robot's own words.
	private static func explainedEvents(timeline: DemoTimeline, language: DemoLanguage) -> [(event: DemoEvent, text: String)] {
		let topLevel = timeline.events.filter { $0.routine == nil && !$0.isSkipped }
		let hasNotes = !(timeline.notes?.steps.isEmpty ?? true)
		return topLevel.compactMap { event -> (event: DemoEvent, text: String)? in
			if hasNotes {
				guard let stepId = event.stepId,
					let note = timeline.notes?.steps[stepId]
				else {
					return nil
				}
				return (event, note.text(in: language))
			}
			return event.isCheck || event.frame != nil ? (event, event.text) : nil
		}
	}

	/// `offset` maps recording seconds onto the rendered video's clock.
	private static func makeCues(explained: [(event: DemoEvent, text: String)], strings: DemoStrings, offset: Double, mainEnd: Double) -> [DemoCue] {
		explained.enumerated().map { index, entry in
			let start = offset + entry.event.startMs / 1000
			let naturalEnd = offset + (entry.event.holdUntilMs ?? entry.event.endMs) / 1000
			let nextStart = explained[safe: index + 1].map { offset + $0.event.startMs / 1000 } ?? mainEnd
			let end = min(max(naturalEnd, start + minimumCueSeconds), nextStart)
			return DemoCue(start: start, end: max(end, start + 0.5), text: entry.text, pointer: pointer(for: entry.event, strings: strings))
		}
	}

	private static func pointer(for event: DemoEvent, strings: DemoStrings) -> DemoPointer? {
		guard let frame = event.frame else {
			return nil
		}
		guard event.isCheck else {
			return DemoPointer(rect: frame, style: .action, badge: nil)
		}
		return DemoPointer(rect: frame, style: event.isPassed ? .passed : .failed, badge: event.isPassed ? strings.asExpected : strings.notAsExpected)
	}
}

/// Fixed card and badge words; English and Bahasa Indonesia only (D-164 user choice).
struct DemoStrings {
	let language: DemoLanguage

	var checksHeading: String {
		language == .english ? "What this checks" : "Yang diuji"
	}

	var whyHeading: String {
		language == .english ? "Why it matters" : "Mengapa penting"
	}

	var setupHeading: String {
		language == .english ? "How the page is set up" : "Kondisi halaman"
	}

	var asExpected: String {
		language == .english ? "✓ As expected" : "✓ Sesuai harapan"
	}

	var notAsExpected: String {
		language == .english ? "✗ Not as expected" : "✗ Tidak sesuai harapan"
	}

	func resultTitle(_ outcome: DemoOutcome) -> String {
		switch outcome {
			case .passed:
				return language == .english ? "Test passed" : "Tes lulus"
			case .failed:
				return language == .english ? "Test failed" : "Tes gagal"
			case .undecided:
				return language == .english ? "Couldn't decide" : "Belum bisa diputuskan"
		}
	}

	func caseHeading(_ caseId: String) -> String {
		language == .english ? "Test case \(caseId)" : "Kasus uji \(caseId)"
	}
}
