import Foundation

/// Which model a Claude run starts on; `auto` lets the server score the case and move up a tier if the run gets stuck (D-158).
enum ClaudeRunModel: String, CaseIterable, Identifiable {
	case auto
	case haiku
	case sonnet
	case opus

	var id: String { rawValue }

	var buttonTitle: LocalizedStringResource {
		switch self {
			case .auto:
				return "Auto — pick by how hard the case looks"
			case .haiku:
				return "Haiku — fastest, for short cases"
			case .sonnet:
				return "Sonnet — most cases"
			case .opus:
				return "Opus — hardest cases"
		}
	}
}
