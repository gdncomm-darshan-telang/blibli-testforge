import Foundation

protocol RunPromptAnswering {
	func answer(promptId: String, answer: RunPromptAnswer, value: String?) async throws
	func showSimulator() async throws
}

/// `/api/prompts/:id`: the answer resumes the waiting run; a value (an OTP) is typed into the simulator by the run.
struct RunPromptService: RunPromptAnswering {
	let client: DashboardClient

	func answer(promptId: String, answer: RunPromptAnswer, value: String?) async throws {
		var body = ["action": answer.rawValue]
		if let value {
			body["value"] = value
		}
		try await client.post(path: "api/prompts/\(promptId)", body: body)
	}

	func showSimulator() async throws {
		try await client.post(path: "api/device/show")
	}
}
