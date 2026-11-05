import Foundation

/// `TestForge --render-demo <folder>` renders a demo without opening a window (the server calls it after a demo
/// replay, D-164); any other launch starts the app.
@main
enum TestForgeMain {
	static func main() {
		let arguments = CommandLine.arguments
		if let previewIndex = arguments.firstIndex(of: "--preview-explain"),
			let folderPath = arguments[safe: previewIndex + 1] {
			let language = DemoLanguage(rawValue: arguments[safe: previewIndex + 2] ?? "") ?? .english
			exit(previewExplain(folder: URL(fileURLWithPath: folderPath), language: language))
		}
		guard let flagIndex = arguments.firstIndex(of: "--render-demo"),
			let folderPath = arguments[safe: flagIndex + 1]
		else {
			TestForgeApp.main()
			return
		}
		exit(renderDemo(folder: URL(fileURLWithPath: folderPath)))
	}

	/// Runs on the main actor (ImageRenderer needs it) without starting the app, then exits.
	private static func previewExplain(folder: URL, language: DemoLanguage) -> Int32 {
		let outcome = DemoRenderOutcome()
		Task { @MainActor in
			do {
				let files = try await ExplainPreviewRenderer(language: language).render(folder: folder)
				outcome.lines = files.map { "preview \($0.path)" }
			} catch {
				outcome.lines = ["error: \(error.localizedDescription)"]
				outcome.status = 1
			}
			outcome.lines.forEach { print($0) }
			exit(outcome.status)
		}
		RunLoop.main.run()
		return outcome.status
	}

	private static func renderDemo(folder: URL) -> Int32 {
		let semaphore = DispatchSemaphore(value: 0)
		let outcome = DemoRenderOutcome()
		Task.detached {
			do {
				let files = try await DemoRenderer().render(folder: folder)
				outcome.lines = files.map { "rendered \($0.lastPathComponent)" }
			} catch {
				outcome.lines = ["error: \(error.localizedDescription)"]
				outcome.status = 1
			}
			semaphore.signal()
		}
		semaphore.wait()
		outcome.lines.forEach { print($0) }
		return outcome.status
	}
}

/// Written once by the render task before it signals, read after the wait — never concurrently.
private final class DemoRenderOutcome: @unchecked Sendable {
	var lines: [String] = []
	var status: Int32 = 0
}
