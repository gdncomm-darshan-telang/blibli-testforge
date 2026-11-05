import Foundation

protocol GitControlling {
	func status(repoPath: String) async throws -> GitRepoStatus
	func fetch(repoPath: String) async throws -> GitRepoStatus

	/// `git merge --ff-only @{u}`; refused when the branch has local commits GitHub doesn't.
	func fastForward(repoPath: String) async throws -> GitRepoStatus

	/// Refused with uncommitted changes unless `isStashing`, and for a branch that doesn't carry TestForge.
	func switchBranch(repoPath: String, branch: String, isStashing: Bool) async throws -> GitRepoStatus

	func restoreStash(repoPath: String) async throws -> GitRepoStatus
}

/// `/api/git/*` (D-200): the developer's own working repo. Builds still come from the QA copy (Prepare code).
struct GitControlService: GitControlling {
	private static let fetchTimeout: TimeInterval = 600

	let client: DashboardClient

	func status(repoPath: String) async throws -> GitRepoStatus {
		let data = try await client.get(path: "api/git/status", queryItems: [URLQueryItem(name: "repo", value: repoPath)])
		return try decode(data)
	}

	func fetch(repoPath: String) async throws -> GitRepoStatus {
		try await post(path: "api/git/fetch", body: ["repo": .string(repoPath)])
	}

	func fastForward(repoPath: String) async throws -> GitRepoStatus {
		try await post(path: "api/git/fast-forward", body: ["repo": .string(repoPath)])
	}

	func switchBranch(repoPath: String, branch: String, isStashing: Bool) async throws -> GitRepoStatus {
		try await post(path: "api/git/switch", body: ["repo": .string(repoPath), "branch": .string(branch), "stash": .bool(isStashing)])
	}

	func restoreStash(repoPath: String) async throws -> GitRepoStatus {
		try await post(path: "api/git/restore-stash", body: ["repo": .string(repoPath)])
	}

	private func post(path: String, body: [String: JSONValue]) async throws -> GitRepoStatus {
		let data = try await client.post(path: path, json: body, timeout: Self.fetchTimeout)
		return try decode(data)
	}

	private func decode(_ data: Data) throws -> GitRepoStatus {
		try JSONDecoder().decode(GitStatusEnvelope.self, from: data).status
	}
}
