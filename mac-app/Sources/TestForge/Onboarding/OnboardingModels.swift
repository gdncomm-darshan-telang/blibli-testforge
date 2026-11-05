import Foundation

enum OnboardingRole: String, CaseIterable, Identifiable {
	case qa
	case developer

	var id: String { rawValue }

	var title: String {
		switch self {
			case .qa:
				return String(localized: "QA")
			case .developer:
				return String(localized: "Developer")
		}
	}

	var subtitle: String {
		switch self {
			case .qa:
				return String(localized: "I test features, run regression and sign off results")
			case .developer:
				return String(localized: "I build features and want to check them before a PR")
		}
	}

	var symbolName: String {
		switch self {
			case .qa:
				return "checkmark.seal"
			case .developer:
				return "chevron.left.forwardslash.chevron.right"
		}
	}
}

/// The tour's pages, in order (D-134).
enum OnboardingStep: Int, CaseIterable, Identifiable {
	case welcome
	case why
	case howItWorks
	case workflow
	case advantages
	case safety
	case start

	var id: Int { rawValue }

	var title: String {
		switch self {
			case .welcome:
				return String(localized: "Welcome")
			case .why:
				return String(localized: "Why it exists")
			case .howItWorks:
				return String(localized: "How it works")
			case .workflow:
				return String(localized: "Your workflow")
			case .advantages:
				return String(localized: "What you gain")
			case .safety:
				return String(localized: "What it never does")
			case .start:
				return String(localized: "Start")
		}
	}

	var isRoleSpecific: Bool {
		self == .workflow || self == .advantages
	}
}

struct OnboardingCard: Identifiable, Equatable {
	let symbolName: String
	let title: String
	let text: String

	var id: String { title }
}

/// One step of a role's day with the app, naming where in the app it happens.
struct OnboardingFlowStep: Identifiable, Equatable {
	let number: Int
	let title: String
	let place: String
	let text: String

	/// Whether the step needs a Claude sign-in (D-148); the app itself and replays never do.
	let needsClaude: Bool

	/// When it's only partly true ("only Run with Claude"), said under the marker.
	let claudeNote: String?

	var id: Int { number }

	init(number: Int, title: String, place: String, text: String, needsClaude: Bool = false, claudeNote: String? = nil) {
		self.number = number
		self.title = title
		self.place = place
		self.text = text
		self.needsClaude = needsClaude
		self.claudeNote = claudeNote
	}
}

struct OnboardingPageContent: Equatable {
	let headline: String
	let intro: String
	let cards: [OnboardingCard]
	let flow: [OnboardingFlowStep]
}

enum OnboardingStartAction: String, CaseIterable, Identifiable {
	case getReady
	case demo
	case claude
	case remote
	case tips

	var id: String { rawValue }

	var title: String {
		switch self {
			case .getReady:
				return String(localized: "Open Get ready")
			case .demo:
				return String(localized: "Watch the demo run")
			case .claude:
				return String(localized: "Ask Claude")
			case .remote:
				return String(localized: "Drive QA from your phone")
			case .tips:
				return String(localized: "Turn on screen tips")
		}
	}

	var text: String {
		switch self {
			case .getReady:
				return String(localized: "Follow the checklist until it is green — everything else needs it.")
			case .demo:
				return String(localized: "About 3 minutes, no Claude: two recorded cases run beside the Simulator, then Results and Reports. Needs Get ready.")
			case .claude:
				return String(localized: "Your own Claude session in this repo: ask about a screen, a run or the code.")
			case .remote:
				return String(localized: "Opens Claude — press Remote Control, turn it on and scan the QR code with your phone.")
			case .tips:
				return String(localized: "Short tips appear the first time you open each screen; replay them from the ? menu.")
		}
	}

	var symbolName: String {
		switch self {
			case .getReady:
				return "checklist"
			case .demo:
				return "play.rectangle"
			case .claude:
				return "sparkles"
			case .remote:
				return "iphone.radiowaves.left.and.right"
			case .tips:
				return "lightbulb"
		}
	}
}

/// What the tour's buttons do outside the tour; set by the TestForge, which owns navigation.
struct OnboardingActions {
	let perform: (OnboardingStartAction) -> Void
	let didClose: () -> Void
}
