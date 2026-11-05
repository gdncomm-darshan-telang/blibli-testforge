/// D-188: which build is under test, and re-checking results a newer build made stale.
extension TutorialCatalog {
	static let buildSteps = [
		TutorialStep(
			anchor: .testsJiraButton,
			title: "Report a result on Jira",
			message: """
				Post to Jira writes the case's result, build, failed step and proof names as a comment on the ticket the test \
				document names (or one you type). You read and edit the whole comment, and nothing posts until you confirm.
				"""
		),
		TutorialStep(
			anchor: .testsRunAllButton,
			title: "Run a batch hands-free",
			message: """
				Run all plans the cases the list shows: replays first, grouped so each environment and login is set up once, \
				then Claude runs. It names anything that would stop it — a manual step, approvals, usage — before you press Start.
				"""
		),
		TutorialStep(
			anchor: .testsBuildLabel,
			title: "Which build you're testing",
			message: """
				Testing … shows the branch, commit and build number under test. Every result records the same, \
				so an export or report says which build passed. An orange label means the installed build isn't from the prepared code.
				"""
		),
		TutorialStep(
			anchor: .testsReplayStaleButton,
			title: "Re-check stale results",
			message: """
				A result goes stale when a newer build changes the code its case covers. Stale cases show a clock badge; \
				Replay stale re-runs their recordings on this build without Claude, so only real failures need a look.
				"""
		)
	]
}
