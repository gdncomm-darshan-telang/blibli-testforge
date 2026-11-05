import Foundation

/// What a new install needs on this Mac before the QA server can start (D-132).
enum SetupTool: String, CaseIterable, Identifiable {
	case xcode
	case node
	case claudeCLI
	case claudeSignIn

	var id: String { rawValue }

	var title: String {
		switch self {
			case .xcode:
				return String(localized: "Xcode")
			case .node:
				return String(localized: "Node.js 18 or newer")
			case .claudeCLI:
				return String(localized: "Claude Code")
			case .claudeSignIn:
				return String(localized: "Signed in to Claude")
		}
	}

	var fix: SetupToolFix {
		switch self {
			case .xcode:
				return .openPage(SetupConstants.Links.xcode)
			case .node:
				return .openPage(SetupConstants.Links.node)
			case .claudeCLI:
				return .openPage(SetupConstants.Links.claudeCode)
			case .claudeSignIn:
				return .signInToClaude
		}
	}
}

enum SetupToolFix: Equatable {
	case openPage(URL?)
	case signInToClaude

	var title: String {
		switch self {
			case .openPage:
				return String(localized: "How to install")
			case .signInToClaude:
				return String(localized: "Sign in")
		}
	}
}

enum ToolCheckResult: Equatable {
	case ready(detail: String)
	case missing(detail: String)
}

enum SetupToolState: Equatable {
	case checking
	case checked(ToolCheckResult)
}

struct SetupToolRowModel: Identifiable, Equatable {
	let tool: SetupTool
	let state: SetupToolState

	var id: String { tool.id }
}

enum SetupRepoState: Equatable {
	case notChosen
	case valid(repo: URL, dashboard: URL)
	case invalid(folder: URL)
}
