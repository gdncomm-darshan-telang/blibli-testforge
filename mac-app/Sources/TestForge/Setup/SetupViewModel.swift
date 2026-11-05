import Foundation

@MainActor
protocol SetupPresenting: ObservableObject {
	var repoState: SetupRepoState { get }

	/// The iOS app clone under test; `.valid`'s `dashboard` holds its `BlibliMobile-iOS` folder.
	var appRepoState: SetupRepoState { get }

	var toolRows: [SetupToolRowModel] { get }
	var message: String? { get }
	var canContinue: Bool { get }

	func chooseRepo()
	func chooseAppRepo()

	/// Settings › Project: picks a repo and, when it holds the QA server, reopens the app on it.
	func changeRepo()

	func checkTools()
	func fix(_ tool: SetupTool)
	func continueToTestForge()
}

struct SetupDependencies {
	let toolChecker: ToolChecking
	let resolver: RepoFolderResolving
	let desktop: DesktopActing
	let system: AppRelaunching & ClaudeSignInOpening
	let defaults: UserDefaults
}

/// First-run setup for an app opened from a DMG: which repo, and whether this Mac has the tools the server needs (D-132).
/// Whole-class `@MainActor` is deliberate: it only orchestrates published state; the probes run in `ToolChecking`.
@MainActor
final class SetupViewModel: SetupPresenting {
	@Published private(set) var repoState: SetupRepoState = .notChosen
	@Published private(set) var appRepoState: SetupRepoState = .notChosen
	@Published private(set) var toolRows: [SetupToolRowModel]
	@Published private(set) var message: String?

	private let dependencies: SetupDependencies
	private var checkTask: Task<Void, Never>?

	var canContinue: Bool {
		guard case .valid = repoState,
			case .valid = appRepoState
		else {
			return false
		}
		return toolRows.allSatisfy { row in
			if case .checked(.ready) = row.state {
				return true
			}
			return false
		}
	}

	init(dependencies: SetupDependencies, currentDashboard: URL?) {
		self.dependencies = dependencies
		toolRows = SetupTool.allCases.map { SetupToolRowModel(tool: $0, state: .checking) }
		if let currentDashboard,
			let repo = dependencies.resolver.repoRoot(containing: currentDashboard) {
			repoState = .valid(repo: repo, dashboard: dependencies.resolver.dashboardDirectory(inRepo: repo))
		}
		let savedProject = dependencies.defaults.string(forKey: TestForgeSettingsKey.projectDirectory)
		if let savedProject {
			let project = URL(fileURLWithPath: savedProject, isDirectory: true)
			appRepoState = .valid(repo: project.deletingLastPathComponent(), dashboard: project)
		}
	}

	deinit {
		checkTask?.cancel()
	}

	func chooseRepo() {
		Task { [weak self] in
			_ = await self?.pickRepo()
		}
	}

	func chooseAppRepo() {
		Task { [weak self] in
			await self?.pickAppRepo()
		}
	}

	func changeRepo() {
		Task { [weak self] in
			guard let self,
				await self.pickRepo()
			else {
				return
			}
			self.reopenOnChosenRepo()
		}
	}

	func checkTools() {
		checkTask?.cancel()
		toolRows = SetupTool.allCases.map { SetupToolRowModel(tool: $0, state: .checking) }
		let checker = dependencies.toolChecker
		checkTask = Task { [weak self] in
			for tool in SetupTool.allCases {
				let result = await checker.check(tool)
				guard !Task.isCancelled else {
					return
				}
				self?.update(tool: tool, result: result)
			}
		}
	}

	func fix(_ tool: SetupTool) {
		switch tool.fix {
			case .openPage(let url):
				guard let url else {
					return
				}
				dependencies.desktop.open(url: url)
			case .signInToClaude:
				do {
					try dependencies.system.openClaudeSignIn()
					message = String(localized: "Finish signing in in the Terminal window, then press Check again.")
				} catch {
					message = String(localized: "Couldn't open sign-in: \(error.localizedDescription)")
				}
		}
	}

	func continueToTestForge() {
		guard canContinue,
			case .valid(_, let dashboard) = repoState,
			case .valid(_, let project) = appRepoState
		else {
			return
		}
		dependencies.defaults.set(project.path, forKey: TestForgeSettingsKey.projectDirectory)
		saveAndRelaunch(dashboard: dashboard)
	}

	private func pickAppRepo() async {
		let prompt = String(localized: "Use this app clone")
		guard let folder = await dependencies.desktop.chooseFolder(prompt: prompt, startingAt: nil) else {
			return
		}
		guard let project = dependencies.resolver.appProjectDirectory(containing: folder) else {
			appRepoState = .invalid(folder: folder)
			return
		}
		appRepoState = .valid(repo: project.deletingLastPathComponent(), dashboard: project)
	}

	/// False when the person cancels the folder panel.
	private func pickRepo() async -> Bool {
		let prompt = String(localized: "Use this repo")
		guard let folder = await dependencies.desktop.chooseFolder(prompt: prompt, startingAt: nil) else {
			return false
		}
		guard let repo = dependencies.resolver.repoRoot(containing: folder) else {
			repoState = .invalid(folder: folder)
			return true
		}
		repoState = .valid(repo: repo, dashboard: dependencies.resolver.dashboardDirectory(inRepo: repo))
		return true
	}

	private func reopenOnChosenRepo() {
		switch repoState {
			case .valid(_, let dashboard):
				saveAndRelaunch(dashboard: dashboard)
			case .invalid(let folder):
				message = String(localized: "\(folder.lastPathComponent) has no server/start.sh — choose the TestForge checkout's top folder")
			case .notChosen:
				break
		}
	}

	private func saveAndRelaunch(dashboard: URL) {
		dependencies.defaults.set(dashboard.path, forKey: TestForgeSettingsKey.dashboardDirectory)
		dependencies.system.relaunch()
	}

	private func update(tool: SetupTool, result: ToolCheckResult) {
		toolRows = toolRows.map { row in
			row.tool == tool ? SetupToolRowModel(tool: tool, state: .checked(result)) : row
		}
	}
}
