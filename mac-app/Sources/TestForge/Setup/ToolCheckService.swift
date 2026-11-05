import Foundation

protocol ToolChecking {
	func check(_ tool: SetupTool) async -> ToolCheckResult
}

/// Probes each tool through a login shell with the same PATH `start.sh` adds, since an app opened from Finder gets a bare one.
struct ToolCheckService: ToolChecking {
	private let runner: CommandRunning

	init(runner: CommandRunning) {
		self.runner = runner
	}

	func check(_ tool: SetupTool) async -> ToolCheckResult {
		switch tool {
			case .xcode:
				return await checkXcode()
			case .node:
				return await checkNode()
			case .claudeCLI:
				return await checkClaudeCLI()
			case .claudeSignIn:
				return await checkClaudeSignIn()
		}
	}

	private func checkXcode() async -> ToolCheckResult {
		guard let output = await shellOutput("xcodebuild -version") else {
			return .missing(detail: String(localized: "Install Xcode from the App Store, open it once, then check again"))
		}
		return .ready(detail: firstLine(of: output))
	}

	private func checkNode() async -> ToolCheckResult {
		guard let output = await shellOutput("node -v") else {
			return .missing(detail: String(localized: "Node.js isn't installed"))
		}
		let version = firstLine(of: output)
		let majorText = version.trimmingCharacters(in: CharacterSet(charactersIn: "v")).split(separator: ".").first
		let major = majorText.flatMap { Int($0) } ?? 0
		guard major >= SetupConstants.Tools.minimumNodeMajor else {
			return .missing(detail: String(localized: "Found \(version) — the QA server needs version \(SetupConstants.Tools.minimumNodeMajor) or newer"))
		}
		return .ready(detail: version)
	}

	private func checkClaudeCLI() async -> ToolCheckResult {
		guard let output = await shellOutput("claude --version") else {
			return .missing(detail: String(localized: "The claude command isn't installed"))
		}
		return .ready(detail: firstLine(of: output))
	}

	private func checkClaudeSignIn() async -> ToolCheckResult {
		guard let output = await shellOutput("claude auth status") else {
			return .missing(detail: String(localized: "Not signed in"))
		}
		let status = output.data(using: .utf8).flatMap { try? JSONDecoder().decode(ClaudeAuthStatus.self, from: $0) }
		guard let status,
			status.isLoggedIn
		else {
			return .missing(detail: String(localized: "Not signed in"))
		}
		let method = status.authMethod ?? "claude.ai"
		return .ready(detail: String(localized: "Signed in (\(method))"))
	}

	/// The tool's output, or nil when it is missing or fails.
	private func shellOutput(_ command: String) async -> String? {
		let script = "export PATH=\"\(SetupConstants.Tools.searchPath)\"; \(command)"
		let request = CommandRequest(executable: SetupConstants.Tools.shell, arguments: ["-lc", script])
		guard let result = try? await runner.run(request),
			result.isSuccess
		else {
			return nil
		}
		return result.output
	}

	private func firstLine(of text: String) -> String {
		let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
		return line.trimmingCharacters(in: .whitespaces)
	}
}

private struct ClaudeAuthStatus: Decodable {
	let isLoggedIn: Bool
	let authMethod: String?

	private enum CodingKeys: String, CodingKey {
		case isLoggedIn = "loggedIn"
		case authMethod
	}
}
