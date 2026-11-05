import Combine
import Foundation

struct GitControlServices {
	let git: GitControlling
	let code: CodePreparing
}

/// Get Ready › Git (D-200): fetch, fast-forward and switch the developer's own working repo, guarded on the server.
/// Whole-class `@MainActor`: it only orchestrates published state; git runs on the server.
@MainActor
final class GitControlViewModel: ObservableObject {
	private static let maxBranchMatches = 60
	private static let preferredRepoNames = ["BlibliIOSApp-POC", "BlibliIOSApp"]

	@Published var isShown = false
	@Published private(set) var phase: GitControlPhase = .loading
	@Published private(set) var repositories: [CodeRepository] = []
	@Published private(set) var status: GitRepoStatus?
	@Published private(set) var busyAction: GitAction?
	@Published private(set) var message: GitMessage?
	@Published private(set) var isLoadingBranches = false
	@Published private(set) var branchLoadError: String?
	@Published var branchQuery = ""
	@Published var pendingSwitch: GitSwitchRequest?

	@Published var selectedRepoPath: String? {
		didSet {
			guard oldValue != selectedRepoPath else {
				return
			}
			status = nil
			branches = []
			message = nil
			refresh()
		}
	}

	@Published private var branches: [CodeBranch] = []

	private let services: GitControlServices
	private var loadTask: Task<Void, Never>?
	private var actionTask: Task<Void, Never>?

	init(services: GitControlServices) {
		self.services = services
	}

	deinit {
		loadTask?.cancel()
		actionTask?.cancel()
	}

	var isBusy: Bool { busyAction != nil }

	var branchMatches: [CodeBranch] {
		let query = branchQuery.trimmingCharacters(in: .whitespaces).lowercased()
		let matches = query.isEmpty ? branches : branches.filter { $0.name.lowercased().contains(query) }
		return Array(matches.prefix(Self.maxBranchMatches))
	}

	var branchCountText: String {
		String(localized: "\(branchMatches.count) of \(branches.count) branches, newest first. Fetch for ones pushed since.")
	}

	var statusContent: GitStatusContent? {
		status.map { GitControlMapper.content(for: $0) }
	}

	var canFastForward: Bool {
		guard let status else {
			return false
		}
		return !isBusy && status.behind > 0 && status.ahead == 0 && status.operation == nil
	}

	func isCurrent(branch: CodeBranch) -> Bool {
		status?.branch == branch.name
	}

	func show() {
		isShown = true
		message = nil
		load()
	}

	func fetch() {
		run(.fetch) { services, path in try await services.git.fetch(repoPath: path) }
	}

	func fastForward() {
		run(.fastForward) { services, path in try await services.git.fastForward(repoPath: path) }
	}

	func restoreStash() {
		run(.restoreStash) { services, path in try await services.git.restoreStash(repoPath: path) }
	}

	/// Uncommitted changes go through `pendingSwitch` first, so nothing is stashed without the person agreeing.
	func requestSwitch(to branch: CodeBranch) {
		guard let status,
			!isCurrent(branch: branch)
		else {
			return
		}
		if status.isDirty {
			pendingSwitch = GitSwitchRequest(branch: branch.name, changedCount: status.changedCount)
			return
		}
		switchBranch(to: branch.name, isStashing: false)
	}

	func confirmStashAndSwitch() {
		guard let request = pendingSwitch else {
			return
		}
		pendingSwitch = nil
		switchBranch(to: request.branch, isStashing: true)
	}

	private func switchBranch(to branch: String, isStashing: Bool) {
		run(.switchBranch(branch)) { services, path in
			try await services.git.switchBranch(repoPath: path, branch: branch, isStashing: isStashing)
		}
	}

	private func run(_ action: GitAction, operation: @escaping (GitControlServices, String) async throws -> GitRepoStatus) {
		guard let path = selectedRepoPath,
			!isBusy
		else {
			return
		}
		busyAction = action
		message = nil
		actionTask?.cancel()
		actionTask = Task { [weak self, services] in
			do {
				let status = try await operation(services, path)
				self?.finish(action: action, status: status)
			} catch {
				self?.busyAction = nil
				self?.message = GitMessage(text: error.localizedDescription, isError: true)
				self?.refresh()
			}
		}
	}

	private func finish(action: GitAction, status: GitRepoStatus) {
		busyAction = nil
		self.status = status
		message = GitControlMapper.message(after: action, status: status)
		loadBranches()
	}

	private func load() {
		phase = .loading
		loadTask?.cancel()
		loadTask = Task { [weak self, services] in
			do {
				let repositories = try await services.code.repositories()
				self?.apply(repositories: repositories)
			} catch {
				self?.phase = .failed(message: error.localizedDescription)
			}
		}
	}

	private func apply(repositories: [CodeRepository]) {
		self.repositories = repositories
		phase = .loaded
		let preferred = Self.preferredRepoNames.lazy.compactMap { name in repositories.first { $0.name == name } }.first
		if selectedRepoPath == nil {
			selectedRepoPath = (preferred ?? repositories.first)?.path
		} else {
			refresh()
		}
	}

	private func refresh() {
		guard let path = selectedRepoPath else {
			return
		}
		Task { [weak self, services] in
			do {
				let status = try await services.git.status(repoPath: path)
				self?.status = status
			} catch {
				self?.message = GitMessage(text: error.localizedDescription, isError: true)
			}
		}
		loadBranches()
	}

	private func loadBranches() {
		guard let path = selectedRepoPath else {
			return
		}
		isLoadingBranches = true
		branchLoadError = nil
		Task { [weak self, services] in
			do {
				let branches = try await services.code.branches(repoPath: path, isAskingGitHub: false)
				self?.branches = branches
			} catch {
				self?.branches = []
				self?.branchLoadError = String(localized: "Couldn't list branches: \(error.localizedDescription)")
			}
			self?.isLoadingBranches = false
		}
	}
}
