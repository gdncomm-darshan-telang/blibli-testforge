import Foundation

protocol RepoFolderResolving {
	/// The repo root holding `tools/qa-dashboard`, for that root or any folder inside it; nil when none is found.
	func repoRoot(containing folder: URL) -> URL?

	func dashboardDirectory(inRepo repo: URL) -> URL
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
}
