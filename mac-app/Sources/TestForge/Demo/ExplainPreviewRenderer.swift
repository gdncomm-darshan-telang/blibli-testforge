import AppKit
import AVFoundation
import SwiftUI

/// `--preview-explain <demo folder>`: the live overlay's real views and mapper drawn over the recording's own frames,
/// one PNG per state, so the overlay can be checked without a Simulator on screen.
@MainActor
struct ExplainPreviewRenderer {
	private static let renderScale: CGFloat = 2

	let language: DemoLanguage

	func render(folder: URL) async throws -> [URL] {
		let timelineURL = folder.appendingPathComponent("timeline.json")
		let timelineData = try Data(contentsOf: timelineURL)
		let timeline = try JSONDecoder().decode(DemoTimeline.self, from: timelineData)
		let rawObject = try JSONSerialization.jsonObject(with: timelineData) as? [String: Any] ?? [:]
		let videoURL = folder.appendingPathComponent(timeline.videoFileName ?? "raw.mp4")
		let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
		generator.appliesPreferredTrackTransform = true
		let outputFolder = folder.appendingPathComponent("explain-preview-\(language.rawValue)")
		try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
		var written: [URL] = []
		for (index, state) in Self.states(timeline: timeline, rawObject: rawObject).enumerated() {
			let fileURL = outputFolder.appendingPathComponent(String(format: "%02d-%@.png", index + 1, state.name))
			let seconds = CMTime(seconds: state.atMs / 1000, preferredTimescale: 600)
			let frame = try? await generator.image(at: seconds).image
			let shot = ExplainPreviewShot(state: state, frame: frame)
			try write(shot: shot, timeline: timeline, to: fileURL)
			written.append(fileURL)
		}
		return written
	}

	private func write(shot: ExplainPreviewShot, timeline: DemoTimeline, to fileURL: URL) throws {
		let state = shot.state
		let screenFrame = CGRect(origin: .zero, size: timeline.screen)
		let geometry = SimulatorGeometry(windowFrame: screenFrame, screenFrame: screenFrame, windowNumber: nil, isWindowOnScreen: true)
		let narrationData = try JSONSerialization.data(withJSONObject: ["runs": [state.run]])
		let narration = try JSONDecoder().decode(NarrationState.self, from: narrationData)
		let inputs = ExplainOverlayInputs(
			narration: narration,
			geometry: geometry,
			fallbackScreen: nil,
			primaryScreenHeight: screenFrame.height,
			language: language,
			now: Date()
		)
		guard let overlay = ExplainOverlayMapper.overlay(inputs: inputs) else {
			return
		}
		let preview = ExplainPreviewView(overlay: overlay, frame: shot.frame)
		let renderer = ImageRenderer(content: preview)
		renderer.scale = Self.renderScale
		guard let image = renderer.cgImage else {
			return
		}
		let bitmap = NSBitmapImageRep(cgImage: image)
		let pngData = bitmap.representation(using: .png, properties: [:])
		try pngData?.write(to: fileURL)
	}

	/// The narration slice as the server would send it at each moment: opening card, each explained step, result.
	private static func states(timeline: DemoTimeline, rawObject: [String: Any]) -> [ExplainPreviewState] {
		let notes = rawObject["notes"] as? [String: Any] ?? [:]
		let noteSteps = notes["steps"] as? [String: Any] ?? [:]
		let rawEvents = rawObject["events"] as? [[String: Any]] ?? []
		let screen: [String: Any] = ["width": timeline.screen.width, "height": timeline.screen.height]
		let baseRun: [String: Any] = ["key": "preview", "caseId": timeline.caseId, "title": timeline.macroName, "screen": screen, "steps": []]
		func run(phase: String, focus: [String: Any]?, verdict: String?) -> [String: Any] {
			var explain = notes
			explain["phase"] = phase
			explain["focus"] = focus ?? NSNull()
			var copy = baseRun
			copy["explain"] = explain
			if let verdict {
				copy["verdict"] = verdict
				copy["endedAt"] = ISO8601DateFormatter().string(from: Date())
			}
			return copy
		}
		let firstMs = (rawEvents.first { noteSteps[$0["id"] as? String ?? ""] != nil && $0["from"] == nil }?["startMs"] as? Double) ?? 0
		var states = [ExplainPreviewState(name: "intro", atMs: firstMs, run: run(phase: "intro", focus: nil, verdict: nil))]
		for event in rawEvents where event["from"] == nil || event["from"] is NSNull {
			guard let stepId = event["id"] as? String,
				noteSteps[stepId] != nil
			else {
				continue
			}
			let isCheck = DemoEvent.checkKinds.contains(event["do"] as? String ?? "")
			let isPassed = event["ok"] as? Bool ?? false
			let style = isCheck ? (isPassed ? "passed" : "failed") : "action"
			let focus: [String: Any] = [
				"style": style,
				"note": noteSteps[stepId] ?? NSNull(),
				"text": event["text"] ?? "",
				"frame": event["frame"] ?? NSNull(),
			]
			let atMs = isCheck ? (event["holdUntilMs"] as? Double ?? event["endMs"] as? Double ?? 0) - 300 : (event["startMs"] as? Double ?? 0) + 300
			states.append(ExplainPreviewState(name: stepId, atMs: atMs, run: run(phase: "steps", focus: focus, verdict: nil)))
		}
		let lastMs = (rawEvents.last?["endMs"] as? Double) ?? firstMs
		states.append(ExplainPreviewState(name: "result", atMs: lastMs, run: run(phase: "result", focus: nil, verdict: timeline.verdict)))
		return states
	}
}

struct ExplainPreviewShot {
	let state: ExplainPreviewState
	let frame: CGImage?
}

struct ExplainPreviewState {
	let name: String
	let atMs: Double
	let run: [String: Any]
}
