import Foundation

protocol CodePreparing {
	func repositories() async throws -> [CodeRepository]

	/// `isAskingGitHub` runs `git ls-remote` (needs the VPN) instead of reading the repo's last fetch.
	func branches(repoPath: String, isAskingGitHub: Bool) async throws -> [CodeBranch]

	/// Nil when nothing has been prepared yet.
	func current() async throws -> PreparedCodeSummary?

	/// Starts the prepare job; a prepare already running answers with its own job id.
	func prepare(repoPath: String, source: CodeSource, branch: String?) async throws -> String

	func result(jobId: String) async throws -> PrepareJobResult
	func cancel(jobId: String) async throws
}

/// `/api/code/*` (D-034/D-035): the QA copy is prepared from a GitHub branch or a snapshot of the working copy.
struct CodePrepareService: CodePreparing {
	private static let gitHubTimeout: TimeInterval = 60

	let client: DashboardClient

	func repositories() async throws -> [CodeRepository] {
		let data = try await client.get(path: "api/code/repos")
		return try JSONDecoder().decode(CodeRepositoryList.self, from: data).repos
	}

	func branches(repoPath: String, isAskingGitHub: Bool) async throws -> [CodeBranch] {
		var queryItems = [URLQueryItem(name: "repo", value: repoPath)]
		if isAskingGitHub {
			queryItems.append(URLQueryItem(name: "refresh", value: "1"))
		}
		let data = try await client.get(path: "api/code/branches", queryItems: queryItems)
		return try JSONDecoder().decode(CodeBranchList.self, from: data).branches
	}

	func current() async throws -> PreparedCodeSummary? {
		let data = try await client.get(path: "api/code/current")
		return try? JSONDecoder().decode(PreparedCodeSummary.self, from: data)
	}

	func prepare(repoPath: String, source: CodeSource, branch: String?) async throws -> String {
		var body: [String: JSONValue] = ["repo": .string(repoPath), "source": .string(source.rawValue)]
		if let branch {
			body["branch"] = .string(branch)
		}
		let data = try await client.post(path: "api/code/prepare", json: body, timeout: Self.gitHubTimeout)
		return try JSONDecoder().decode(PrepareJobStart.self, from: data).jobId
	}

	func result(jobId: String) async throws -> PrepareJobResult {
		let data = try await client.get(path: "api/code/prepare/\(jobId)")
		return try JSONDecoder().decode(PrepareJobResult.self, from: data)
	}

	func cancel(jobId: String) async throws {
		try await client.post(path: "api/jobs/\(jobId)/cancel")
	}
}
