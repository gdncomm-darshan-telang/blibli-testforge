import CoreGraphics
import Foundation
import SwiftUI

struct ExplainCardSection: Equatable, Identifiable {
	let heading: String
	let body: String

	var id: String {
		heading
	}
}

struct ExplainCard: Equatable {
	let title: String
	let sections: [ExplainCardSection]

	/// Set on the result card only.
	var outcome: DemoOutcome? = nil
}

/// Rect in panel points, top-left origin.
struct ExplainPointer: Equatable {
	let rect: CGRect
	let style: DemoPointerStyle
	let badge: String?
}

extension ExplainPointer {
	var color: Color {
		Color(nsColor: DemoLayout.color(for: style))
	}

	/// The drawn box, a little outside the element so it never covers the element's edge.
	func outlineRect(width: CGFloat) -> CGRect {
		let inset = -width * ExplainOverlayConstants.Pointer.insetShare
		return rect.insetBy(dx: inset, dy: inset)
	}

	/// Above the element when there is room, otherwise below it; the subtitle placement keeps clear of it.
	func badgeFrame(width: CGFloat) -> CGRect? {
		guard let badge else {
			return nil
		}
		let metrics = ExplainOverlayConstants.Pointer.self
		let fontSize = width * metrics.badgeShare
		let height = fontSize * metrics.badgeHeightFontShare
		let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
		let textWidth = ceil((badge as NSString).size(withAttributes: [.font: font]).width)
		let outline = outlineRect(width: width)
		let gap = width * metrics.badgeGapShare
		let aboveY = outline.minY - height - gap
		let originY = aboveY > 0 ? aboveY : outline.maxY + gap
		let originX = max(outline.minX, width * metrics.badgeMarginShare)
		return CGRect(x: originX, y: originY, width: textWidth + fontSize * metrics.badgePadFontShare * 2, height: height)
	}
}

struct ExplainCaption: Equatable {
	/// Nil when the macro has notes but none for this step: the pointer still shows, no words.
	let text: String?

	let pointer: ExplainPointer?

	/// Worked out per step from where the element is (D-207); nil when there are no words.
	let placement: ExplainCaptionPlacement?
}

enum ExplainOverlayContent: Equatable {
	case card(ExplainCard)
	case caption(ExplainCaption)
}

/// What the live overlay draws over the Simulator screen for an explained replay (D-165).
struct ExplainOverlay: Equatable {
	/// The Simulator's device screen, in AppKit coordinates.
	let panelFrame: CGRect

	let content: ExplainOverlayContent
}

/// A spinner and what the phone is busy with, over a replay that has nothing else to show yet.
struct StepBusyOverlay: Equatable {
	/// The Simulator's device screen, in AppKit coordinates.
	let panelFrame: CGRect

	let message: String
}

/// What the step-overlay panel shows: the plain step outline, the explained replay's overlay, or a busy banner.
enum StepOverlayContent: Equatable {
	case outline(StepOutline)
	case explain(ExplainOverlay)
	case busy(StepBusyOverlay)

	var panelFrame: CGRect {
		switch self {
			case .outline(let outline):
				return outline.panelFrame
			case .explain(let overlay):
				return overlay.panelFrame
			case .busy(let overlay):
				return overlay.panelFrame
		}
	}
}

enum StepBusyMapper {
	/// The running replay's busy message on the Simulator screen; nil when the phone is doing nothing to wait for.
	static func overlay(narration: NarrationState?, geometry: SimulatorGeometry, primaryScreenHeight: CGFloat) -> StepBusyOverlay? {
		guard let busy = narration?.runs.first(where: { $0.isRunning })?.busy,
			!busy.message.isEmpty
		else {
			return nil
		}
		let panelFrame = ScreenCoordinates.appKitRect(fromAccessibilityRect: geometry.screenFrame, primaryScreenHeight: primaryScreenHeight)
		return StepBusyOverlay(panelFrame: panelFrame, message: busy.message)
	}
}

struct ExplainOverlayInputs {
	let narration: NarrationState?
	let geometry: SimulatorGeometry
	let fallbackScreen: DeviceScreen?
	let primaryScreenHeight: CGFloat
	let language: DemoLanguage
	let now: Date
}

enum ExplainOverlayMapper {
	/// Long enough to read the result card after the replay ends.
	static let resultSeconds: TimeInterval = 5

	/// The explained run to show: the running one, or one that ended within the result card's time.
	static func activeRun(narration: NarrationState?, now: Date) -> NarratedRun? {
		narration?.runs.first { run in
			guard run.explain != nil else {
				return false
			}
			guard let endedAt = run.endedAt else {
				return true
			}
			return now.timeIntervalSince(endedAt) < resultSeconds
		}
	}

	static func overlay(inputs: ExplainOverlayInputs) -> ExplainOverlay? {
		guard let run = activeRun(narration: inputs.narration, now: inputs.now),
			let explain = run.explain
		else {
			return nil
		}
		let panelFrame = ScreenCoordinates.appKitRect(fromAccessibilityRect: inputs.geometry.screenFrame, primaryScreenHeight: inputs.primaryScreenHeight)
		let strings = DemoStrings(language: inputs.language)
		// System prep messages stay in the TestForge's Tests pane (D-206); viewers only see what the test checks.
		switch explain.phase {
			case .intro:
				let card = introCard(run: run, explain: explain, strings: strings)
				return ExplainOverlay(panelFrame: panelFrame, content: .card(card))
			case .result:
				let card = resultCard(run: run, explain: explain, strings: strings)
				return ExplainOverlay(panelFrame: panelFrame, content: .card(card))
			case .steps:
				guard let focus = explain.focus,
					!focus.isRoutine
				else {
					// A setup routine's steps point at nothing worth showing viewers.
					return nil
				}
				let caption = caption(focus: focus, run: run, inputs: inputs)
				return ExplainOverlay(panelFrame: panelFrame, content: .caption(caption))
		}
	}

	private static func introCard(run: NarratedRun, explain: NarratedExplain, strings: DemoStrings) -> ExplainCard {
		let language = strings.language
		let candidates: [(String, DemoText?)] = [
			(strings.checksHeading, explain.checks),
			(strings.whyHeading, explain.why),
			(strings.setupHeading, explain.setup),
		]
		let sections = candidates.compactMap { heading, text in
			text.map { ExplainCardSection(heading: heading, body: $0.text(in: language)) }
		}
		return ExplainCard(title: explain.title?.text(in: language) ?? run.title, sections: sections)
	}

	private static func resultCard(run: NarratedRun, explain: NarratedExplain, strings: DemoStrings) -> ExplainCard {
		let outcome = DemoOutcome(verdict: run.verdict)
		let heading = strings.caseHeading(run.caseId ?? "")
		let body = explain.title?.text(in: strings.language) ?? run.title
		let section = ExplainCardSection(heading: heading, body: body)
		return ExplainCard(title: strings.resultTitle(outcome), sections: [section], outcome: outcome)
	}

	private static func caption(focus: NarratedFocus, run: NarratedRun, inputs: ExplainOverlayInputs) -> ExplainCaption {
		let hasNotes = run.explain?.title != nil
		let text = focus.note?.text(in: inputs.language) ?? (hasNotes ? nil : focus.text)
		let pointer = pointer(focus: focus, run: run, inputs: inputs)
		let screen = inputs.geometry.screenFrame.size
		let placement = text.map { text in
			let badgeFrames = pointer?.badgeFrame(width: screen.width).map { [$0] } ?? []
			let target = pointer?.outlineRect(width: screen.width)
			let layout = ExplainCaptionLayoutInputs(text: text, target: target, avoid: badgeFrames, screen: screen)
			return ExplainCaptionPlacer.placement(inputs: layout)
		}
		return ExplainCaption(text: text, pointer: pointer, placement: placement)
	}

	private static func pointer(focus: NarratedFocus, run: NarratedRun, inputs: ExplainOverlayInputs) -> ExplainPointer? {
		guard let deviceFrame = focus.frame,
			let devicePoints = run.screen?.size ?? inputs.fallbackScreen?.size
		else {
			return nil
		}
		let geometry = inputs.geometry
		let mapping = ScreenMapping(screenFrame: geometry.screenFrame, devicePoints: devicePoints)
		guard mapping.isCalibrated else {
			return nil
		}
		let macRect = mapping.macRect(forDeviceRect: deviceFrame)
		let rect = macRect.offsetBy(dx: -geometry.screenFrame.minX, dy: -geometry.screenFrame.minY)
		let strings = DemoStrings(language: inputs.language)
		switch focus.style {
			case .passed:
				return ExplainPointer(rect: rect, style: .passed, badge: strings.asExpected)
			case .failed:
				return ExplainPointer(rect: rect, style: .failed, badge: strings.notAsExpected)
			case .checking:
				return ExplainPointer(rect: rect, style: .checking, badge: nil)
			case .action,
				.step:
				return ExplainPointer(rect: rect, style: .action, badge: nil)
		}
	}
}
