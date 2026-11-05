import SwiftUI

/// First-run screen: choose the repo, see which tools are missing, then continue into the TestForge.
struct SetupView<ViewModel: SetupPresenting>: View {
	@ObservedObject var viewModel: ViewModel

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
				header
				repoSection
				toolsSection
				footer
			}
			.padding(TestForgeConstants.Spacing.large)
			.frame(maxWidth: SetupConstants.Layout.width)
			.frame(maxWidth: .infinity)
		}
		.onAppear(perform: viewModel.checkTools)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(SetupConstants.Accessibility.screen)
	}

	@ViewBuilder
	private var header: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text("Set up TestForge")
				.font(.largeTitle.bold())
			Text("TestForge tests your own copy of the iOS repo. Choose that folder and check this Mac has the tools below — you do this once.")
				.foregroundStyle(.secondary)
		}
	}

	@ViewBuilder
	private var repoSection: some View {
		GroupBox("1 · iOS repo") {
			HStack(alignment: .firstTextBaseline) {
				repoText
					.frame(maxWidth: .infinity, alignment: .leading)
				Button("Choose…", action: viewModel.chooseRepo)
					.accessibilityIdentifier(SetupConstants.Accessibility.chooseRepoButton)
			}
			.padding(TestForgeConstants.Spacing.medium)
		}
	}

	@ViewBuilder
	private var repoText: some View {
		switch viewModel.repoState {
			case .notChosen:
				Text("Choose the folder you cloned BlibliIOSApp into (the one with tools/qa-dashboard).")
					.foregroundStyle(.secondary)
			case .valid(let repo, _):
				Label(repo.path, systemImage: "checkmark.circle.fill")
					.foregroundStyle(.green)
					.textSelection(.enabled)
			case .invalid(let folder):
				Label("\(folder.lastPathComponent) has no tools/qa-dashboard — choose the repo's top folder", systemImage: "xmark.octagon.fill")
					.foregroundStyle(.red)
		}
	}

	@ViewBuilder
	private var toolsSection: some View {
		GroupBox("2 · Tools on this Mac") {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
				ForEach(viewModel.toolRows) { row in
					SetupToolRowView(row: row) {
						viewModel.fix(row.tool)
					}
				}
			}
			.padding(TestForgeConstants.Spacing.medium)
		}
	}

	@ViewBuilder
	private var footer: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			if let message = viewModel.message {
				Text(message)
					.foregroundStyle(.secondary)
			}
			HStack {
				Button("Check again", systemImage: "arrow.clockwise", action: viewModel.checkTools)
					.accessibilityIdentifier(SetupConstants.Accessibility.recheckButton)
				Spacer()
				Button("Continue", action: viewModel.continueToTestForge)
					.keyboardShortcut(.defaultAction)
					.disabled(!viewModel.canContinue)
					.help("TestForge reopens with this repo and starts its QA server")
					.accessibilityIdentifier(SetupConstants.Accessibility.continueButton)
			}
		}
	}
}
