import AppKit

protocol AppRelaunching {
	/// Opens a fresh copy of this app, then quits this one, so the new repo folder is read at launch.
	@MainActor
	func relaunch()
}

protocol ClaudeSignInOpening {
	/// `claude auth login` asks questions in a terminal, so it opens in Terminal once; everything after stays in the app.
	func openClaudeSignIn() throws
}

struct SetupSystem: AppRelaunching, ClaudeSignInOpening {
	private let workspace: NSWorkspace
	private let application: NSApplication
	private let fileManager: FileManager

	init(workspace: NSWorkspace = .shared, application: NSApplication = .shared, fileManager: FileManager = .default) {
		self.workspace = workspace
		self.application = application
		self.fileManager = fileManager
	}

	@MainActor
	func relaunch() {
		let configuration = NSWorkspace.OpenConfiguration()
		configuration.createsNewApplicationInstance = true
		let application = application
		workspace.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
			DispatchQueue.main.async {
				application.terminate(nil)
			}
		}
	}

	func openClaudeSignIn() throws {
		let scriptURL = fileManager.temporaryDirectory.appendingPathComponent("testforge-claude-sign-in.command")
		let script = """
		#!/bin/zsh -l
		export PATH="\(SetupConstants.Tools.searchPath)"
		claude auth login
		echo
		echo "Done — go back to TestForge and press Check again."
		"""
		try script.write(to: scriptURL, atomically: true, encoding: .utf8)
		try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
		workspace.open(scriptURL)
	}
}
