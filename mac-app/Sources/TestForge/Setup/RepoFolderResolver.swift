import Foundation

protocol RepoFolderResolving {
	/// The TestForge checkout holding `server/start.sh`, for that root or any folder inside it; nil when none is found.
	func repoRoot(containing folder: URL) -> URL?

	func dashboardDirectory(inRepo repo: URL) -> URL

	/// The `BlibliMobile-iOS` folder (the one holding the `.xcworkspace`) of an app clone, given the clone root or that folder; nil when none.
	func appProjectDirectory(containing folder: URL) -> URL?
}

struct RepoFolderResolver: RepoFolderResolving {
	private let fileManager: FileManager

	init(fileManager: FileManager = .default) {
		self.fileManager = fileManager
	}

	func repoRoot(containing folder: URL) -> URL? {
		var candidate = folder.standardizedFileURL
		for _ in 0..<SetupConstants.Repo.searchDepth {
			let serverScript = dashboardDirectory(inRepo: candidate).appendingPathComponent(SetupConstants.Repo.serverScript)
			if fileManager.fileExists(atPath: serverScript.path) {
				return candidate
			}
			let parent = candidate.deletingLastPathComponent()
			guard parent != candidate else {
				return nil
			}
			candidate = parent
		}
		return nil
	}

	func dashboardDirectory(inRepo repo: URL) -> URL {
		repo.appendingPathComponent(SetupConstants.Repo.dashboardPath, isDirectory: true)
	}

	func appProjectDirectory(containing folder: URL) -> URL? {
		let standardized = folder.standardizedFileURL
		let nested = standardized.appendingPathComponent(SetupConstants.Repo.appProjectFolder, isDirectory: true)
		return [standardized, nested].first { hasWorkspace(in: $0) }
	}

	private func hasWorkspace(in directory: URL) -> Bool {
		let entries = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
		return entries.contains { $0.hasSuffix(".\(SetupConstants.Repo.workspaceExtension)") }
	}
}
