import Foundation
import Testing
@testable import TestForge

@Suite("RepoFolderResolver")
struct RepoFolderResolverTests {
	private let resolver = RepoFolderResolver()

	private func makeTempDirectory() throws -> URL {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
		return url.standardizedFileURL
	}

	private func touch(_ path: URL) throws {
		try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
		FileManager.default.createFile(atPath: path.path, contents: Data())
	}

	@Test("appProjectDirectory finds the workspace in the folder itself")
	func appProjectDirectoryInFolder() throws {
		let root = try makeTempDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		try FileManager.default.createDirectory(
			at: root.appendingPathComponent("Blibli.xcworkspace"),
			withIntermediateDirectories: true
		)
		#expect(resolver.appProjectDirectory(containing: root) == root)
	}

	@Test("appProjectDirectory finds BlibliMobile-iOS under the clone root")
	func appProjectDirectoryNested() throws {
		let root = try makeTempDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		let nested = root.appendingPathComponent(SetupConstants.Repo.appProjectFolder, isDirectory: true)
		try FileManager.default.createDirectory(
			at: nested.appendingPathComponent("Blibli.xcworkspace"),
			withIntermediateDirectories: true
		)
		#expect(resolver.appProjectDirectory(containing: root) == nested)
	}

	@Test("appProjectDirectory is nil without a workspace")
	func appProjectDirectoryMissing() throws {
		let root = try makeTempDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		#expect(resolver.appProjectDirectory(containing: root) == nil)
	}

	@Test("repoRoot finds the checkout from the root and from a folder inside it")
	func repoRootFound() throws {
		let root = try makeTempDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		try touch(root.appendingPathComponent("server/start.sh"))
		let inside = root.appendingPathComponent("mac-app/Sources", isDirectory: true)
		try FileManager.default.createDirectory(at: inside, withIntermediateDirectories: true)
		#expect(resolver.repoRoot(containing: root) == root)
		#expect(resolver.repoRoot(containing: inside) == root)
	}

	@Test("repoRoot is nil when no server/start.sh is above the folder")
	func repoRootMissing() throws {
		let root = try makeTempDirectory()
		defer { try? FileManager.default.removeItem(at: root) }
		#expect(resolver.repoRoot(containing: root) == nil)
	}

	@Test("dashboardDirectory is server/ in the repo")
	func dashboardDirectory() {
		let repo = URL(fileURLWithPath: "/tmp/testforge", isDirectory: true)
		#expect(resolver.dashboardDirectory(inRepo: repo).path == "/tmp/testforge/server")
	}
}
