import AVFoundation
import Foundation
import QuartzCore

enum DemoRenderError: LocalizedError {
	case missingFile(String)
	case noVideoTrack
	case exportFailed(String)

	var errorDescription: String? {
		switch self {
			case .missingFile(let name):
				return "The demo folder has no \(name)."
			case .noVideoTrack:
				return "The recording has no video."
			case .exportFailed(let reason):
				return "Exporting the demo failed: \(reason)"
		}
	}
}

/// D-164: turns a demo folder (`raw.mp4` + `timeline.json`) into `demo-en.mp4`, `demo-id.mp4` and matching `.vtt` subtitles.
/// The first and last frames are held under the opening and closing cards; the recording itself is never altered.
struct DemoRenderer {
	/// Sharp on a Mac screen and in full screen; recordings narrower than this keep their own width.
	static let outputWidth: CGFloat = 1080

	private let fileManager: FileManager

	init(fileManager: FileManager = .default) {
		self.fileManager = fileManager
	}

	/// Returns the files written, in render order.
	func render(folder: URL) async throws -> [URL] {
		let timelineURL = folder.appendingPathComponent("timeline.json")
		guard let timelineData = fileManager.contents(atPath: timelineURL.path) else {
			throw DemoRenderError.missingFile("timeline.json")
		}
		let timeline = try JSONDecoder().decode(DemoTimeline.self, from: timelineData)
		let rawURL = folder.appendingPathComponent(timeline.videoFileName ?? "raw.mp4")
		guard fileManager.fileExists(atPath: rawURL.path) else {
			throw DemoRenderError.missingFile(rawURL.lastPathComponent)
		}
		var written: [URL] = []
		for language in DemoLanguage.allCases {
			let videoURL = folder.appendingPathComponent("demo-\(language.rawValue).mp4")
			let subtitleURL = folder.appendingPathComponent("demo-\(language.rawValue).vtt")
			let script = try await renderVideo(source: rawURL, timeline: timeline, language: language, output: videoURL)
			try DemoSubtitles.webVTT(for: script).write(to: subtitleURL, atomically: true, encoding: .utf8)
			written += [videoURL, subtitleURL]
		}
		return written
	}

	private func renderVideo(source: URL, timeline: DemoTimeline, language: DemoLanguage, output: URL) async throws -> DemoScript {
		let asset = AVURLAsset(url: source)
		guard let sourceTrack = try await asset.loadTracks(withMediaType: .video).first else {
			throw DemoRenderError.noVideoTrack
		}
		let duration = try await asset.load(.duration)
		let naturalSize = try await sourceTrack.load(.naturalSize)
		let script = DemoScript(timeline: timeline, language: language, recordingSeconds: duration.seconds)
		let composition = AVMutableComposition()
		guard let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
			throw DemoRenderError.noVideoTrack
		}
		let trim = CMTime(seconds: script.trimSeconds, preferredTimescale: 600)
		try insertHeldFrames(into: track, source: sourceTrack, range: CMTimeRange(start: trim, end: duration))
		let width = min(Self.outputWidth, naturalSize.width)
		let scale = width / naturalSize.width
		// H.264 wants even dimensions.
		let renderSize = CGSize(width: Self.evenFloor(width), height: Self.evenFloor(naturalSize.height * scale))
		let videoComposition = makeVideoComposition(track: track, total: composition.duration, renderSize: renderSize, scale: scale)
		let pointScale = timeline.screen.width > 0 ? renderSize.width / timeline.screen.width : scale
		let overlay = DemoOverlayBuilder(renderSize: renderSize, pointScale: pointScale).overlay(for: script)
		let parent = CALayer()
		parent.frame = CGRect(origin: .zero, size: renderSize)
		let videoLayer = CALayer()
		videoLayer.frame = parent.frame
		parent.addSublayer(videoLayer)
		parent.addSublayer(overlay)
		videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)
		try await export(composition: composition, videoComposition: videoComposition, to: output)
		return script
	}

	private static func evenFloor(_ value: CGFloat) -> CGFloat {
		(value / 2).rounded(.down) * 2
	}

	/// Opening card over the first frame held, the recording, closing card over the last frame held.
	private func insertHeldFrames(into track: AVMutableCompositionTrack, source: AVAssetTrack, range: CMTimeRange) throws {
		let sliver = CMTime(value: 1, timescale: 30)
		let introLength = CMTime(seconds: DemoScript.introSeconds, preferredTimescale: 600)
		let outroLength = CMTime(seconds: DemoScript.outroSeconds, preferredTimescale: 600)
		try track.insertTimeRange(CMTimeRange(start: range.start, duration: sliver), of: source, at: .zero)
		track.scaleTimeRange(CMTimeRange(start: .zero, duration: sliver), toDuration: introLength)
		try track.insertTimeRange(range, of: source, at: introLength)
		let outroStart = CMTimeAdd(introLength, range.duration)
		try track.insertTimeRange(CMTimeRange(start: CMTimeSubtract(range.end, sliver), duration: sliver), of: source, at: outroStart)
		track.scaleTimeRange(CMTimeRange(start: outroStart, duration: sliver), toDuration: outroLength)
	}

	private func makeVideoComposition(track: AVMutableCompositionTrack, total: CMTime, renderSize: CGSize, scale: CGFloat) -> AVMutableVideoComposition {
		let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
		layerInstruction.setTransform(CGAffineTransform(scaleX: scale, y: scale), at: .zero)
		let instruction = AVMutableVideoCompositionInstruction()
		instruction.timeRange = CMTimeRange(start: .zero, duration: total)
		instruction.layerInstructions = [layerInstruction]
		let videoComposition = AVMutableVideoComposition()
		videoComposition.instructions = [instruction]
		videoComposition.renderSize = renderSize
		videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
		return videoComposition
	}

	private func export(composition: AVComposition, videoComposition: AVVideoComposition, to output: URL) async throws {
		try? fileManager.removeItem(at: output)
		// Medium and Low presets cap the frame at about 480 px tall whatever the render size, which made demos blurry.
		guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
			throw DemoRenderError.exportFailed("no export session")
		}
		session.videoComposition = videoComposition
		session.outputURL = output
		session.outputFileType = .mp4
		session.shouldOptimizeForNetworkUse = true
		await session.export()
		guard session.status == .completed else {
			throw DemoRenderError.exportFailed(session.error?.localizedDescription ?? "status \(session.status.rawValue)")
		}
	}
}

/// WebVTT beside each video, so Teams, Jira and Confluence players can switch the subtitles on or off.
enum DemoSubtitles {
	static func webVTT(for script: DemoScript) -> String {
		var lines = ["WEBVTT", ""]
		let introText = ([script.intro.title] + script.intro.sections.map { "\($0.heading): \($0.body)" }).joined(separator: "\n")
		lines += cue(start: script.intro.start, end: script.intro.end, text: introText)
		for item in script.cues {
			lines += cue(start: item.start, end: item.end, text: [item.text, item.pointer?.badge].compactMap { $0 }.joined(separator: " — "))
		}
		let outroText = ([script.outro.title] + script.outro.sections.map { "\($0.heading): \($0.body)" }).joined(separator: "\n")
		lines += cue(start: script.outro.start, end: script.outro.end, text: outroText)
		return lines.joined(separator: "\n")
	}

	private static func cue(start: Double, end: Double, text: String) -> [String] {
		["\(timestamp(start)) --> \(timestamp(end))", text, ""]
	}

	static func timestamp(_ seconds: Double) -> String {
		let totalMilliseconds = Int((max(seconds, 0) * 1000).rounded())
		let hours = totalMilliseconds / 3_600_000
		let minutes = totalMilliseconds / 60_000 % 60
		let wholeSeconds = totalMilliseconds / 1000 % 60
		let milliseconds = totalMilliseconds % 1000
		return String(format: "%02d:%02d:%02d.%03d", hours, minutes, wholeSeconds, milliseconds)
	}
}
