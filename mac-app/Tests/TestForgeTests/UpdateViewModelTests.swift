import Foundation
import Testing
@testable import TestForge

@MainActor
private final class FakeUpdater: AppUpdating {
	var status: UpdateStatus
	var updateResult: Result<URL, UpdateError>
	private(set) var updateCalls = 0

	init(status: UpdateStatus, updateResult: Result<URL, UpdateError> = .success(URL(fileURLWithPath: "/tmp/TestForge.app"))) {
		self.status = status
		self.updateResult = updateResult
	}

	func checkStatus() async throws -> UpdateStatus {
		status
	}

	func update(progress: @escaping @MainActor (UpdatePhase) -> Void) async throws -> URL {
		updateCalls += 1
		await progress(.building)
		return try updateResult.get()
	}
}

@MainActor
private final class FakeRelauncher: AppRelaunching {
	private(set) var relaunchedAt: URL?
	func relaunch() {}
	func relaunch(at url: URL) {
		relaunchedAt = url
	}
}

private func waiting(_ count: Int) -> UpdateStatus {
	UpdateStatus(state: .available(count: count), currentCommit: "aaa1111", latestCommit: "bbb2222", incoming: ["A change"])
}

@MainActor
@Suite("UpdateViewModel")
struct UpdateViewModelTests {
	private func settle() async {
		for _ in 0..<20 {
			await Task.yield()
		}
	}

	@Test("a check stores the status and returns to idle")
	func check() async {
		let viewModel = UpdateViewModel(service: FakeUpdater(status: waiting(2)), system: FakeRelauncher())
		viewModel.check()
		#expect(viewModel.activity == .checking)
		await settle()
		#expect(viewModel.status == waiting(2))
		#expect(viewModel.activity == .idle)
		#expect(viewModel.canUpdate)
	}

	@Test("the menu names the update when one is waiting")
	func menuTitle() async {
		let viewModel = UpdateViewModel(service: FakeUpdater(status: waiting(3)), system: FakeRelauncher())
		#expect(viewModel.menuTitle.contains("Check"))
		viewModel.checkQuietly()
		await settle()
		#expect(viewModel.menuTitle.contains("3"))
	}

	@Test("update does nothing until a check found one")
	func updateNeedsCheck() async {
		let updater = FakeUpdater(status: waiting(1))
		let viewModel = UpdateViewModel(service: updater, system: FakeRelauncher())
		viewModel.update()
		await settle()
		#expect(updater.updateCalls == 0)
	}

	@Test("a good update relaunches the rebuilt app")
	func updateRelaunches() async {
		let relauncher = FakeRelauncher()
		let viewModel = UpdateViewModel(service: FakeUpdater(status: waiting(1)), system: relauncher)
		viewModel.check()
		await settle()
		viewModel.update()
		await settle()
		#expect(relauncher.relaunchedAt?.lastPathComponent == "TestForge.app")
	}

	@Test("a failed update shows the failure and keeps running")
	func updateFails() async {
		let relauncher = FakeRelauncher()
		let updater = FakeUpdater(status: waiting(1), updateResult: .failure(.buildFailed("error: boom")))
		let viewModel = UpdateViewModel(service: updater, system: relauncher)
		viewModel.check()
		await settle()
		viewModel.update()
		await settle()
		#expect(viewModel.message?.contains("boom") == true)
		#expect(viewModel.activity == .idle)
		#expect(relauncher.relaunchedAt == nil)
	}
}
