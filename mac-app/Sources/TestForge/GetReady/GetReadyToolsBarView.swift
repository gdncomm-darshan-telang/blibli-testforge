import SwiftUI

/// Always reachable, not only when a check fails: switch the branch under test, or see what's waiting for the simulator.
struct GetReadyToolsBarView: View {
	let companions: GetReadyCompanions

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Button("Prepare code…", systemImage: "arrow.triangle.branch") {
				companions.prepareCode.show()
			}
			.help("Choose the GitHub branch or working copy the QA build is made from")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.getReadyPrepareCodeButton)
			.tutorialAnchor(.getReadyPrepareCode)
			Button("Run queue…", systemImage: "list.number") {
				companions.runQueue.show()
			}
			.help("What holds the simulator, what waits, and what just finished")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.getReadyRunQueueButton)
			.tutorialAnchor(.getReadyRunQueue)
			Button("Git…", systemImage: "point.3.connected.trianglepath.dotted") {
				companions.git.show()
			}
			.help("Fetch, update or switch your own working copy")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.getReadyGitButton)
			.tutorialAnchor(.getReadyGit)
			Spacer()
		}
	}
}
