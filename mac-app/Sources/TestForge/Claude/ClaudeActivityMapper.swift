import Foundation

struct ClaudeActivityModel: Equatable {
	let activityText: String
	let systemImage: String
	let stepsText: String
	let costText: String
	let modelText: String?
	let isWorking: Bool
}

/// D-192: what a Claude session is doing right now, in words, from its newest tool call — the line a terminal never gives.
enum ClaudeActivityMapper {
	static func activity(items: [ClaudeTranscriptItem], summary: ClaudeSessionSummary) -> ClaudeActivityModel? {
		let tools = items.compactMap { item -> (name: String, argument: String)? in
			guard case .tool(let name, let argument, _) = item.kind else {
				return nil
			}
			return (name, argument)
		}
		let model = items.reversed().lazy.compactMap { item -> String? in
			guard case .started(let model) = item.kind else {
				return nil
			}
			return model
		}.first
		guard !tools.isEmpty || model != nil else {
			return nil
		}
		let isWorking = summary.status == "running"
		let latest = tools.last
		let (verb, symbol) = latest.map { describe(toolName: $0.name) } ?? (String(localized: "Starting"), "sparkles")
		let argument = latest?.argument.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		let activityText: String
		if !isWorking {
			activityText = ClaudeTranscriptMapper.statusTitle(summary.status)
		} else if argument.isEmpty {
			activityText = verb
		} else {
			activityText = "\(verb) · \(argument.prefix(80))"
		}
		return ClaudeActivityModel(
			activityText: activityText,
			systemImage: isWorking ? symbol : "pause.circle",
			stepsText: String(localized: "\(tools.count) steps"),
			costText: summary.costUsd.formatted(.currency(code: "USD").precision(.fractionLength(2))),
			modelText: model,
			isWorking: isWorking
		)
	}

	/// Driver and NetworkLens tools in a tester's words; anything else by its family.
	static func describe(toolName: String) -> (String, String) {
		let name = toolName.lowercased()
		let table: [(String, String, String)] = [
			("screenshot", String(localized: "Looking at the screen"), "camera.viewfinder"),
			("tap", String(localized: "Tapping"), "hand.tap"),
			("swipe", String(localized: "Scrolling"), "arrow.up.and.down"),
			("scroll", String(localized: "Scrolling"), "arrow.up.and.down"),
			("type", String(localized: "Typing"), "keyboard"),
			("assert", String(localized: "Checking"), "checkmark.seal"),
			("wait", String(localized: "Waiting for the app"), "hourglass"),
			("dump_tree", String(localized: "Reading the screen's elements"), "list.bullet.indent"),
			("get_label", String(localized: "Reading a label"), "text.magnifyingglass"),
			("deeplink", String(localized: "Opening a page"), "link"),
			("relaunch", String(localized: "Relaunching the app"), "arrow.clockwise"),
			("recording", String(localized: "Recording the screen"), "record.circle"),
			("lens_", String(localized: "Working with network mocks"), "network"),
			("confluence", String(localized: "Reading Confluence"), "doc.text"),
			("jira", String(localized: "Reading Jira"), "ticket"),
		]
		if let match = table.first(where: { name.contains($0.0) }) {
			return (match.1, match.2)
		}
		switch toolName {
			case "Read", "Grep", "Glob":
				return (String(localized: "Reading code"), "doc.text.magnifyingglass")
			case "Edit", "Write":
				return (String(localized: "Editing a file"), "pencil")
			case "Bash":
				return (String(localized: "Running a command"), "terminal")
			case "Skill":
				return (String(localized: "Using a skill"), "wand.and.stars")
			default:
				return (String(localized: "Working"), "gearshape")
		}
	}
}
