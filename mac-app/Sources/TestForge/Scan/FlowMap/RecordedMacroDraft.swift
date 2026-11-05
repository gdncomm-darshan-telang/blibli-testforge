import Foundation

struct RecordedMacroCaseOption: Equatable, Identifiable {
	let id: String
	let title: String
}

/// What the Save as macro sheet edits; the steps themselves stay on the map.
struct RecordedMacroDraft: Equatable, Identifiable {
	let id = UUID()
	var name: String
	var caseId: String
	var module: String
	var submodule: String
	var isFreshStart: Bool
	let stepCount: Int
	let caseOptions: [RecordedMacroCaseOption]

	/// One line per tap without an accessibility ID, so the person sees them before saving.
	let missingIdentifierWarnings: [String]

	var canSave: Bool {
		!name.trimmingCharacters(in: .whitespaces).isEmpty && !module.trimmingCharacters(in: .whitespaces).isEmpty
	}
}

struct RecordedMacroOutcome: Equatable, Identifiable {
	let id = UUID()
	let title: String
	let message: String
}
