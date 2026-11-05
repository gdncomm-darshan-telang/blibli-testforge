import Foundation

enum CaseResultOverrideVerdict: String, CaseIterable, Identifiable {
	case pass = "PASS"
	case fail = "FAIL"
	case blocked = "BLOCKED"
	case undecided = "UNDECIDED"

	var id: String { rawValue }

	var title: LocalizedStringResource {
		switch self {
			case .pass:
				return "Pass"
			case .fail:
				return "Fail"
			case .blocked:
				return "Blocked"
			case .undecided:
				return "Undecided"
		}
	}
}

enum CaseResultOverrideLeniency: String, CaseIterable, Identifiable {
	case strict
	case lenient

	var id: String { rawValue }

	var title: LocalizedStringResource {
		switch self {
			case .strict:
				return "Strict"
			case .lenient:
				return "Lenient"
		}
	}

	var explanation: LocalizedStringResource {
		switch self {
			case .strict:
				return "Reruns judge every detail of the expected result."
			case .lenient:
				return "Reruns pass when the main behaviour holds; small differences the expected result doesn't name are not failures."
		}
	}
}

struct CaseResultOverrideHistoryRow: Equatable, Identifiable {
	let id: Int
	let changeText: String
	let detailText: String
	let reason: String
}

/// What a person fills in the Override result sheet (D-180); the description is required.
struct CaseResultOverrideDraft: Equatable, Identifiable {
	let id: String
	let scenario: String
	let currentVerdictText: String
	let history: [CaseResultOverrideHistoryRow]
	var verdict: CaseResultOverrideVerdict
	var leniency: CaseResultOverrideLeniency
	var reason: String

	/// Starts as the expected result runs use now; a change is saved as a local edit of the case.
	var expected: String

	var canSave: Bool {
		!reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}
}
