/// D-199: what moved here from the web UI — Prepare code, the run queue, test logins and run popups.
extension TutorialCatalog {
	static let toolSteps = [
		TutorialStep(
			anchor: .getReadyPrepareCode,
			title: "Choose the code under test",
			message: """
				Prepare code picks a GitHub branch or a snapshot of your working copy and copies it to a separate QA folder; \
				your own repo is only read. Get Ready then asks for a build when the app no longer matches it. \
				Which folders TestForge uses (its own checkout and your iOS clone) is set once at first launch; change them in Settings › Project.
				"""
		),
		TutorialStep(
			anchor: .getReadyGit,
			title: "Fetch and switch your own repo",
			message: """
				Git fetches from GitHub, fast-forwards your branch and switches it. Uncommitted work is never lost: \
				the switch stops, or stashes it when you say so, and Restore stash brings it back. Builds still use Prepare code.
				"""
		),
		TutorialStep(
			anchor: .getReadyRunQueue,
			title: "Who's next on the simulator",
			message: """
				Run queue shows what holds the simulator, what waits behind it and what just finished. \
				Move a waiting run up or down, cancel one, or retry a finished one.
				"""
		),
		TutorialStep(
			anchor: .getReadyChecks,
			title: "When a run needs you",
			message: """
				A run that meets a system popup it can't tap, or a production OTP it can't know, opens a sheet here: \
				do it on the simulator or type the code, then the run carries on. Test logins live in Settings › Logins.
				"""
		),
	]
}
