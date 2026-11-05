import SwiftUI

/// Get Ready › Git (D-200): your own working repo — fetch, update, switch. Builds still come from Prepare code's QA copy.
struct GitControlSheetView: View {
	@ObservedObject var viewModel: GitControlViewModel
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			Text("Git")
				.font(.title2.weight(.semibold))
			Text("Your own working copy. Builds and tests still use the QA copy from Prepare code; switch here, then prepare.")
				.font(.callout)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
			content
			footer
		}
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(minWidth: TestForgeConstants.GetReady.gitWidth, minHeight: TestForgeConstants.GetReady.gitHeight, alignment: .topLeading)
		.confirmationDialog(switchTitle, isPresented: isSwitchPresented, presenting: viewModel.pendingSwitch) { _ in
			Button("Stash and switch") {
				viewModel.confirmStashAndSwitch()
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.gitStashAndSwitch)
			Button("Cancel", role: .cancel) {
				viewModel.pendingSwitch = nil
			}
		} message: { request in
			Text("\(request.changedCount) uncommitted change(s), untracked files included, go into git stash. Restore stash brings them back.")
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.gitSheet)
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.phase {
			case .loading:
				LoadingStateView(text: "Reading your repositories…")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .failed(let message):
				ContentUnavailableView("Couldn't read your repositories", systemImage: "exclamationmark.triangle", description: Text(message))
			case .loaded:
				controls
		}
	}

	private var controls: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Picker("Repository", selection: $viewModel.selectedRepoPath) {
				ForEach(viewModel.repositories) { repository in
					Text(repository.name)
						.tag(Optional(repository.path))
				}
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.gitRepository)
			if let content = viewModel.statusContent {
				GitStatusCardView(content: content)
				actions(hasStash: content.hasStash)
			} else {
				LoadingStateView(text: "Reading git status…")
			}
			messageRow
			branchPicker
		}
	}

	private func actions(hasStash: Bool) -> some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Button("Fetch", systemImage: "arrow.down.circle") {
				viewModel.fetch()
			}
			.disabled(viewModel.isBusy)
			.help("git fetch --prune origin: new branches and commits from GitHub; your files don't change (needs the VPN)")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.gitFetch)
			Button("Update branch", systemImage: "arrow.up.forward.circle") {
				viewModel.fastForward()
			}
			.disabled(!viewModel.canFastForward)
			.help("Fast-forward to GitHub's copy of this branch; never merges or rewrites")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.gitFastForward)
			if hasStash {
				Button("Restore stash", systemImage: "tray.and.arrow.up") {
					viewModel.restoreStash()
				}
				.disabled(viewModel.isBusy)
				.help("Bring back the changes the app stashed before a switch")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.gitRestoreStash)
			}
			Spacer()
			if let busyAction = viewModel.busyAction {
				ProgressView()
					.controlSize(.small)
				Text(busyAction.progressText)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
	}

	@ViewBuilder
	private var messageRow: some View {
		if let message = viewModel.message,
			!message.text.isEmpty
		{
			Label(message.text, systemImage: message.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
				.font(.callout)
				.foregroundStyle(message.isError ? .orange : .green)
				.textSelection(.enabled)
				.fixedSize(horizontal: false, vertical: true)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.gitMessage)
		}
	}

	private var branchPicker: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			TextField("Search branches, e.g. release/v15.0.0", text: $viewModel.branchQuery)
				.textFieldStyle(.roundedBorder)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.gitBranchField)
			List(viewModel.branchMatches) { branch in
				GitBranchRowView(branch: branch, isCurrent: viewModel.isCurrent(branch: branch), isDisabled: viewModel.isBusy) {
					viewModel.requestSwitch(to: branch)
				}
			}
			.frame(minHeight: TestForgeConstants.GetReady.branchListMaxHeight)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.gitBranchList)
			branchListStatus
		}
	}

	@ViewBuilder
	private var branchListStatus: some View {
		if viewModel.isLoadingBranches {
			HStack(spacing: TestForgeConstants.Spacing.small) {
				ProgressView()
					.controlSize(.small)
				Text("Listing branches…")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.accessibilityElement(children: .combine)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.gitBranchesLoading)
		} else if let branchLoadError = viewModel.branchLoadError {
			Label(branchLoadError, systemImage: "exclamationmark.triangle")
				.foregroundStyle(.orange)
				.font(.caption)
				.textSelection(.enabled)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.gitBranchesFailure)
		} else {
			Text(viewModel.branchCountText)
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}

	private var footer: some View {
		HStack {
			Spacer()
			Button("Done") {
				dismiss()
			}
			.keyboardShortcut(.defaultAction)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.gitDone)
		}
	}

	private var switchTitle: Text {
		Text("Stash your changes and switch to \(viewModel.pendingSwitch?.branch ?? "")?")
	}

	private var isSwitchPresented: Binding<Bool> {
		Binding {
			viewModel.pendingSwitch != nil
		} set: { isPresented in
			if !isPresented {
				viewModel.pendingSwitch = nil
			}
		}
	}
}
