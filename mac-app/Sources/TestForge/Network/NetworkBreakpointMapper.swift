import Foundation

struct BreakpointRowModel: Identifiable, Equatable {
	let id: String
	let endpoint: String
	let detailText: String
}

struct HeldCallModel: Identifiable, Equatable {
	let id: String
	let endpoint: String
	let detailText: String
	let statusText: String
	let body: String
	let isResponse: Bool

	/// False for a body that is not text: it can continue or fail, but not be edited here.
	let canEditBody: Bool
}

struct BreakpointsDisplayModel: Equatable {
	let breakpoints: [BreakpointRowModel]
	let held: [HeldCallModel]
}

/// `/api/lens/breakpoints` answers → Breakpoints tab display models (D-130).
enum NetworkBreakpointMapper {
	static func display(_ answer: LensBreakpointsResponse, now: Date) -> BreakpointsDisplayModel {
		BreakpointsDisplayModel(breakpoints: answer.breakpoints.map(row), held: held(answer.held, now: now))
	}

	static func held(_ calls: [LensHeldCall], now: Date) -> [HeldCallModel] {
		calls.map { call in
			let heldSeconds = call.pausedAt.map { Int(now.timeIntervalSince($0).rounded()) } ?? 0
			let resumeText = autoResumeText(call, now: now)
			let target = call.url ?? call.endpointKey
			let heldText = String(localized: "held \(heldSeconds) s")
			return HeldCallModel(
				id: call.id,
				endpoint: call.endpointKey,
				detailText: "\(stageTitle(call.stage)) · \(heldText) · \(resumeText) · \(target)",
				statusText: call.statusCode.map(String.init) ?? "",
				body: call.body ?? String(localized: "(binary body, \(call.bodyByteCount) bytes)"),
				isResponse: call.stage == "response",
				canEditBody: call.body != nil
			)
		}
	}

	static func replayMessage(_ answer: LensReplayResponse) -> String {
		if answer.isInFlight {
			return String(localized: "Replay sent — still waiting (held by a breakpoint or slow); it shows up in Traffic when it lands")
		}
		if let failure = answer.failure {
			return String(localized: "Replayed — failed: \(failure)")
		}
		let statusText = answer.statusCode.map(String.init) ?? "—"
		return answer.isMockServed
			? String(localized: "Replayed — \(statusText) (mocked)")
			: String(localized: "Replayed — \(statusText)")
	}

	private static func row(_ breakpoint: LensBreakpoint) -> BreakpointRowModel {
		var parts = [stageTitle(breakpoint.stage)]
		if breakpoint.isOneShot {
			parts.append(String(localized: "once"))
		}
		if !breakpoint.isEnabled {
			parts.append(String(localized: "off"))
		}
		if let url = breakpoint.url {
			parts.append(url)
		}
		return BreakpointRowModel(id: breakpoint.id, endpoint: breakpoint.endpointKey, detailText: parts.joined(separator: " · "))
	}

	/// The app lets a held call go on its own at 80 % of the request's timeout, so the tester sees the deadline.
	private static func autoResumeText(_ call: LensHeldCall, now: Date) -> String {
		guard call.isAutoResumeEnabled,
			let deadline = call.autoResumeAt
		else {
			return String(localized: "no auto-continue")
		}
		let seconds = max(0, Int(deadline.timeIntervalSince(now).rounded()))
		return String(localized: "continues by itself in \(seconds) s")
	}

	private static func stageTitle(_ stage: String) -> String {
		NetworkBreakpointStage(rawValue: stage)?.title ?? stage
	}
}
