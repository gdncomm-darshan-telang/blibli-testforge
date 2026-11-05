/// D-194/D-195: Scan's step editor and tap fallback, and what a case feeds the app.
extension TutorialCatalog {
	static let inputSteps = [
		TutorialStep(
			anchor: .testsInputsPanel,
			title: "Deeplinks and mocks of a case",
			message: """
				Under a recorded case: every deeplink its recording opens and every mocked response it arms, with status and body. \
				Copy one, download one as .json, or Download all for a single file to hand a developer.
				"""
		),
	]

	static let verifySteps = [
		TutorialStep(
			anchor: .testsVerifyButton,
			title: "Check your branch before the PR",
			message: """
				Verify my changes compares your code with a branch (develop by default, uncommitted edits included) and picks \
				the loaded cases whose recordings cover what changed. Replay opens the batch plan; nothing runs until Start.
				"""
		),
	]

	static let physicalDeviceSteps = [
		TutorialStep(
			anchor: .simulatorPhysicalDevices,
			title: "Real iPhones too",
			message: """
				Real devices lists every iPhone and iPad paired with this Mac, connected first. Choose one to see whether tests \
				can run on it and what's missing; simulators stay the test device until a device-signed QA build exists.
				"""
		),
	]

	static let stepEditorSteps = [
		TutorialStep(
			anchor: .scanEditStepsButton,
			title: "Fix a macro without its JSON",
			message: """
				Edit steps lists the macro's steps: drag to reorder, remove one, change how long a tap waits, mark it Skip if not there, \
				or change typed text. Save writes the macro file; what each step taps stays as recorded.
				"""
		),
		TutorialStep(
			anchor: .scanRecordButton,
			title: "Taps without an ID still replay",
			message: """
				A tap on something with no accessibility ID is saved as its position inside the nearest element that has one, \
				and a system alert (Allow, Open, OK) is saved as an alert answer that's skipped when the alert doesn't show.
				"""
		),
	]
}
