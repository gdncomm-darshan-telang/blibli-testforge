import Foundation

/// The text a person edits in the Edit case sheet (D-166); starts from what currently runs.
struct TestCaseDraft: Equatable, Identifiable {
	let id: String
	var scenario: String
	var precondition: String
	var steps: String
	var expected: String
	var api: String

	init(testCase: TestCaseSummary) {
		id = testCase.id
		scenario = testCase.scenario ?? ""
		precondition = testCase.precondition ?? ""
		steps = testCase.steps ?? ""
		expected = testCase.expected ?? ""
		api = testCase.api ?? ""
	}

	var canSave: Bool {
		!scenario.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	/// Every field goes up; the server keeps only the ones that differ from the document.
	var serverFields: [String: String] {
		["scenario": scenario, "precondition": precondition, "steps": steps, "expected": expected, "api": api]
	}
}
