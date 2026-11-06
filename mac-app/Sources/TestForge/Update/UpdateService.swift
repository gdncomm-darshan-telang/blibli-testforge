import Foundation

protocol AppUpdating {
	/// Fetches origin/master and says whether this checkout can fast-forward to it.
	func checkStatus() async throws -> UpdateStatus

	/// Pulls master (fast-forward only), rebuilds the app and returns the new app bundle.
	func update(progress: @escaping @MainActor (UpdatePhase) -> Void) async throws -> URL
}

/// Updates the TestForge checkout the app runs from: `git fetch`, `git pull --ff-only`, `mac-app/scripts/make-app.sh` (D-217).
struct GitAppUpdateService: AppUpdating {
	private let runner: CommandRunning
	private let repo: URL?

	init(runner: CommandRunning, repo: URL?) {
		self.runner = runner
		self.repo = repo
	}

	func checkStatus() async throws -> UpdateStatus {
		let repo = try requireRepo()
		let remote = "\(UpdateConstants.remoteName)/\(UpdateConstants.trunkBranch)"
		let fetch = try await git(in: repo, ["-c", UpdateConstants.batchSSH, "fetch", "--quiet", UpdateConstants.remoteName, UpdateConstants.trunkBranch])
		guard fetch.isSuccess else {
			throw UpdateError.fetchFailed(fetch.summary)
		}
		let branch = try await text(in: repo, ["rev-parse", "--abbrev-ref", "HEAD"])
		let isDirty = try await !text(in: repo, ["status", "--porcelain"]).isEmpty
		let counts = try await text(in: repo, ["rev-list", "--left-right", "--count", "HEAD...\(remote)"])
			.split(whereSeparator: { $0 == "\t" || $0 == " " })
			.compactMap { Int($0) }
		let ahead = counts[safe: 0] ?? 0
		let behind = counts[safe: 1] ?? 0
		let current = try await text(in: repo, ["rev-parse", "--short", "HEAD"])
		let latest = try await text(in: repo, ["rev-parse", "--short", remote])
		let incoming = behind > 0
			? try await text(in: repo, ["log", "--format=%s", "-n", "\(UpdateConstants.incomingLimit)", "HEAD..\(remote)"])
				.split(separator: "\n").map(String.init)
			: []
		return UpdateStatus(
			state: Self.state(branch: branch, isDirty: isDirty, ahead: ahead, behind: behind),
			currentCommit: current,
			latestCommit: latest,
			incoming: incoming
		)
	}

	func update(progress: @escaping @MainActor (UpdatePhase) -> Void) async throws -> URL {
		let repo = try requireRepo()
		guard case .available = try await checkStatus().state else {
			throw UpdateError.notUpdatable
		}
		await progress(.pulling)
		let pull = try await git(in: repo, ["-c", UpdateConstants.batchSSH, "pull", "--ff-only", UpdateConstants.remoteName, UpdateConstants.trunkBranch])
		guard pull.isSuccess else {
			throw UpdateError.pullFailed(pull.summary)
		}
		await progress(.building)
		let build = try await runner.run(CommandRequest(
			executable: UpdateConstants.shellPath,
			arguments: ["-c", "export PATH=\"\(SetupConstants.Tools.searchPath)\"; \(UpdateConstants.buildScript)", "zsh", repo.path]
		))
		guard build.isSuccess else {
			throw UpdateError.buildFailed(Self.tail(of: build.errorOutput.isEmpty ? build.output : build.errorOutput))
		}
		let app = repo.appendingPathComponent(UpdateConstants.builtAppPath, isDirectory: true)
		guard FileManager.default.fileExists(atPath: app.path) else {
			throw UpdateError.builtAppMissing
		}
		return app
	}

	static func state(branch: String, isDirty: Bool, ahead: Int, behind: Int) -> UpdateStatus.State {
		if branch != UpdateConstants.trunkBranch {
			return .blocked(.notOnTrunk(branch: branch))
		}
		if behind == 0 {
			return .upToDate
		}
		if isDirty {
			return .blocked(.localChanges)
		}
		if ahead > 0 {
			return .blocked(.diverged)
		}
		return .available(count: behind)
	}

	/// The last few lines of a build log: that is where the compiler says what went wrong.
	static func tail(of output: String) -> String {
		output
			.split(separator: "\n", omittingEmptySubsequences: true)
			.suffix(UpdateConstants.errorTailLines)
			.joined(separator: "\n")
	}

	private func requireRepo() throws -> URL {
		guard let repo else {
			throw UpdateError.noCheckout
		}
		return repo
	}

	private func git(in repo: URL, _ arguments: [String]) async throws -> CommandOutput {
		try await runner.run(CommandRequest(executable: UpdateConstants.gitPath, arguments: ["-C", repo.path] + arguments))
	}

	private func text(in repo: URL, _ arguments: [String]) async throws -> String {
		try await git(in: repo, arguments).output.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
