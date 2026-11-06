import Foundation
import Testing
@testable import TestForge

@MainActor
@Suite("Setup gating")
struct SetupGatingTests {
	private struct Opener: TestForgeOpening {}

	private let base = URL(string: "http://127.0.0.1:4545")!
	private let folder = URL(fileURLWithPath: "/tmp/testforge/server", isDirectory: true)

	@Test("no checkout needs Setup")
	func noLocation() {
		#expect(Opener().isSetupNeeded(for: nil))
	}

	@Test("checkout without an iOS clone needs Setup")
	func noProject() {
		let location = ServerLocation(dashboardDirectory: folder, baseURL: base, projectDirectory: nil)
		#expect(Opener().isSetupNeeded(for: location))
	}

	@Test("checkout and iOS clone skip Setup")
	func complete() {
		let project = URL(fileURLWithPath: "/tmp/app/BlibliMobile-iOS", isDirectory: true)
		let location = ServerLocation(dashboardDirectory: folder, baseURL: base, projectDirectory: project)
		#expect(!Opener().isSetupNeeded(for: location))
	}
}
