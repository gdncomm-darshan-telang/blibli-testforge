import Foundation

protocol TestCaseActing {
	/// A Confluence page loads through Claude in the background; the `testcases` slice reports progress.
	func loadDocument(source: String) async throws

	func replay(recordingId: String) async throws

	func replayWithExplanations(recordingId: String) async throws

	func recordDemo(recordingId: String) async throws

	/// One Claude turn writes the English and Bahasa explanations into the recording; takes about a minute.
	func writeExplanations(recordingId: String, isRewrite: Bool) async throws

	/// Spends Claude usage, so callers confirm with the user first.
	func runWithClaude(caseId: String, model: ClaudeRunModel) async throws

	func cancelRun(jobId: String) async throws

	/// Runs the cases as one batch: recorded ones replay, the rest go to Claude; the server refuses unless Get ready is green.
	func startBatch(caseIds: [String]) async throws

	/// D-193: the case's tickets from the document and the comment its result would post.
	func jiraDraft(caseId: String) async throws -> JiraDraft

	/// Posts to Jira; callers reach it only from the person's confirmation.
	func postJira(caseId: String, key: String, comment: String) async throws

	/// D-191: what a batch of these cases will do and what could stop it.
	func planBatch(caseIds: [String]) async throws -> BatchPlan

	/// D-196: the loaded cases whose recordings cover the branch's diff against `base`.
	func verifyPlan(base: String, isIncludingLocal: Bool) async throws -> VerifyPlan

	/// D-188: replays every stale case that has a recording, no Claude; the server picks the cases.
	func replayStale() async throws

	/// Stored beside the document and laid over it on every load; the document itself is never written.
	func saveEdit(caseId: String, draft: TestCaseDraft) async throws

	func revertEdit(caseId: String) async throws

	/// D-180: records the person's verdict with its required reason; `shouldRerun` also starts a Claude run that reads it.
	func overrideResult(draft: CaseResultOverrideDraft, shouldRerun: Bool) async throws

	/// D-183: the case's screenshots and videos in the active test batch, oldest first.
	func media(caseId: String) async throws -> [URL]
}

/// Same endpoints as the web UI's Test Cases tab, so a run started here shows in both apps.
struct TestCaseService: TestCaseActing {
	/// Claude writes both languages in one turn; it has taken about a minute.
	private static let explanationTimeout: TimeInterval = 300

	private let client: DashboardClient

	init(client: DashboardClient) {
		self.client = client
	}

	func loadDocument(source: String) async throws {
		try await client.post(path: "api/testcases/load", body: ["path": source])
	}

	func replay(recordingId: String) async throws {
		try await client.post(path: "api/macros/v2/\(recordingId)/replay")
	}

	func replayWithExplanations(recordingId: String) async throws {
		try await client.post(path: "api/macros/v2/\(recordingId)/replay", json: ["explain": .bool(true)])
	}

	func recordDemo(recordingId: String) async throws {
		try await client.post(path: "api/demo/\(recordingId)/record")
	}

	func writeExplanations(recordingId: String, isRewrite: Bool) async throws {
		let body: [String: JSONValue] = ["overwrite": .bool(isRewrite)]
		try await client.post(path: "api/demo/\(recordingId)/notes", json: body, timeout: Self.explanationTimeout)
	}

	func runWithClaude(caseId: String, model: ClaudeRunModel) async throws {
		try await client.post(path: "api/testcases/\(caseId)/run", body: ["model": model.rawValue])
	}

	func cancelRun(jobId: String) async throws {
		try await client.post(path: "api/jobs/\(jobId)/cancel")
	}

	func startBatch(caseIds: [String]) async throws {
		let ids = JSONValue.array(caseIds.map { JSONValue.string($0) })
		try await client.post(path: "api/batch", json: ["caseIds": ids])
	}

	func jiraDraft(caseId: String) async throws -> JiraDraft {
		let data = try await client.get(path: "api/testcases/\(caseId)/jira")
		return try JSONDecoder().decode(JiraDraft.self, from: data)
	}

	func postJira(caseId: String, key: String, comment: String) async throws {
		let json: [String: JSONValue] = ["key": .string(key), "comment": .string(comment), "confirmed": .bool(true)]
		_ = try await client.post(path: "api/testcases/\(caseId)/jira", json: json, timeout: 180)
	}

	func planBatch(caseIds: [String]) async throws -> BatchPlan {
		let ids = JSONValue.array(caseIds.map { JSONValue.string($0) })
		let data = try await client.post(path: "api/batch/plan", json: ["caseIds": ids])
		return try JSONDecoder().decode(BatchPlan.self, from: data)
	}

	func verifyPlan(base: String, isIncludingLocal: Bool) async throws -> VerifyPlan {
		let data = try await client.post(path: "api/verify/plan", json: ["base": .string(base), "includeLocal": .bool(isIncludingLocal)])
		return try JSONDecoder().decode(VerifyPlan.self, from: data)
	}

	func replayStale() async throws {
		_ = try await client.post(path: "api/batch/stale")
	}

	func saveEdit(caseId: String, draft: TestCaseDraft) async throws {
		let fields = draft.serverFields.mapValues { JSONValue.string($0) }
		try await client.put(path: "api/testcases/\(caseId)/edit", json: ["fields": .object(fields)])
	}

	func revertEdit(caseId: String) async throws {
		try await client.delete(path: "api/testcases/\(caseId)/edit")
	}

	func overrideResult(draft: CaseResultOverrideDraft, shouldRerun: Bool) async throws {
		let body: [String: JSONValue] = [
			"verdict": .string(draft.verdict.rawValue),
			"reason": .string(draft.reason),
			"leniency": .string(draft.leniency.rawValue),
			"expected": .string(draft.expected),
			"rerun": .bool(shouldRerun),
		]
		try await client.put(path: "api/testcases/\(draft.id)/result", json: body)
	}

	func media(caseId: String) async throws -> [URL] {
		let data = try await client.get(path: "api/testcases/\(caseId)/media")
		return try JSONDecoder().decode(TestCaseMediaList.self, from: data).urls
	}
}
