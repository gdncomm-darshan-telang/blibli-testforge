/// D-189: Reports › Batches.
extension TutorialCatalog {
	static let batchSteps = [
		TutorialStep(
			anchor: .batchesList,
			title: "Every Test Batch in one place",
			message: """
				Reports › Batches lists every batch, active first, with how many cases passed and failed. \
				Choose one to read its report; ending a batch opens its report here.
				"""
		),
		TutorialStep(
			anchor: .batchesProgress,
			title: "Progress that keeps",
			message: """
				Counts are per case, latest result wins, and they're saved on the batch itself, \
				so they survive a restart and never lose old runs.
				"""
		),
		TutorialStep(
			anchor: .batchesPause,
			title: "Switch priorities without ending a batch",
			message: """
				Pause sets the active batch aside: nothing joins it and its report stays open. Start or resume another for the \
				urgent work, then Resume this one — the batch active then is paused in its place, never ended.
				"""
		),
		TutorialStep(
			anchor: .batchesReopen,
			title: "Reopen or tidy up",
			message: """
				Reopen makes an ended batch active again; new work and proof join it, and the active batch is paused. \
				Remove takes a batch off the list; its folder and report stay on disk.
				"""
		),
		TutorialStep(
			anchor: .batchesReplay,
			title: "Regression on a new build",
			message: """
				After Prepare code and a new build, Replay on this build reruns every recorded case of an ended batch, \
				with no Claude, into a new batch. Its header says what regressed, what got fixed and what stayed the same.
				"""
		),
	]

	/// D-190/D-192: what this Mac needs, and following a Claude run better than a terminal.
	static let claudeRunSteps = [
		TutorialStep(
			anchor: .claudeActivityStrip,
			title: "What Claude is doing now",
			message: """
				The line above the conversation says what Claude is doing in plain words — tapping, looking at the screen, \
				reading code — with its steps, cost and model. While a run goes, one-click replies steer it: ask for a screenshot, \
				point it at the recording, or have it say what's blocking it.
				"""
		),
	]

	static let prerequisiteSteps = [
		TutorialStep(
			anchor: .getReadyChecks,
			title: "Everything this Mac needs",
			message: """
				Tools on this Mac and Claude Code plugin + MCP servers list what's missing. \
				Show what's missing opens each tool, plugin and MCP server with the one command or step that fixes it, ready to copy.
				"""
		),
	]
}
