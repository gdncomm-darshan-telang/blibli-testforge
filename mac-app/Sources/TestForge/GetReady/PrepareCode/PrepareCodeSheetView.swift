import SwiftUI

/// Get Ready › Prepare code (D-199): choose the code the QA copy holds, then watch it get copied and its packages resolved.
struct PrepareCodeSheetView: View {
	@ObservedObject var viewModel: PrepareCodeViewModel
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			Text("Prepare code")
				.font(.title2.weight(.semibold))
			content
			footer
		}
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(minWidth: TestForgeConstants.GetReady.prepareCodeWidth, minHeight: TestForgeConstants.GetReady.prepareCodeHeight, alignment: .topLeading)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.prepareCodeSheet)
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.phase {
			case .loading:
				LoadingStateView(text: "Reading your repositories…")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .failed(let message):
				ContentUnavailableView("Couldn't read the code", systemImage: "exclamationmark.triangle", description: Text(message))
			case .choosing:
				chooser
			case .preparing, .finished:
				progressList
		}
	}

	private var chooser: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			PreparedCodeSummaryView(current: viewModel.current)
			Picker("Repository", selection: $viewModel.selectedRepoPath) {
				ForEach(viewModel.repositories) { repository in
					Text("\(repository.name) — \(repository.branch)")
						.tag(Optional(repository.path))
				}
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.prepareCodeRepository)
			Picker("Code from", selection: $viewModel.source) {
				ForEach(CodeSource.allCases) { source in
					Text(source.title)
						.tag(source)
				}
			}
			.pickerStyle(.segmented)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.prepareCodeSource)
			switch viewModel.source {
				case .github:
					branchChooser
				case .local:
					Text(viewModel.localNote)
						.font(.callout)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
						.accessibilityIdentifier(TestForgeConstants.Accessibility.prepareCodeLocalNote)
			}
		}
	}

	private var branchChooser: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			HStack {
				TextField("Search branches, e.g. release/v15.0.0", text: $viewModel.branchQuery)
					.textFieldStyle(.roundedBorder)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.prepareCodeBranchField)
				Button {
					viewModel.askGitHub()
				} label: {
					if viewModel.isAskingGitHub {
						ProgressView()
							.controlSize(.small)
					} else {
						Label("Check GitHub", systemImage: "arrow.clockwise")
					}
				}
				.disabled(viewModel.isAskingGitHub)
				.help("Ask GitHub for its latest branches (needs the VPN)")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.prepareCodeAskGitHub)
			}
			List(viewModel.branchMatches) { branch in
				BranchMatchRowView(branch: branch, isSelected: branch.name == viewModel.selectedBranch) {
					viewModel.choose(branch: branch)
				}
			}
			.frame(maxHeight: TestForgeConstants.GetReady.branchListMaxHeight)
			Text(viewModel.branchNote)
				.font(.caption)
				.foregroundStyle(.secondary)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.prepareCodeBranchNote)
		}
	}

	private var progressList: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			List(viewModel.progress) { line in
				PrepareProgressRowView(line: line)
			}
			if case .finished(let message, let isSuccess) = viewModel.phase {
				Label(message, systemImage: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
					.foregroundStyle(isSuccess ? .green : .orange)
					.textSelection(.enabled)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.prepareCodeResult)
			}
		}
	}

	private var footer: some View {
		HStack {
			if viewModel.phase == .preparing {
				Button(role: .destructive) {
					viewModel.cancel()
				} label: {
					ActionProgressLabel(title: String(localized: "Cancel prepare"), busyTitle: String(localized: "Cancelling…"), isBusy: viewModel.isCancelling)
				}
				.disabled(viewModel.isCancelling)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.prepareCodeCancel)
				if let cancelError = viewModel.cancelError {
					Label(cancelError, systemImage: "exclamationmark.triangle")
						.foregroundStyle(.orange)
						.font(.callout)
						.accessibilityIdentifier(TestForgeConstants.Accessibility.prepareCodeCancelFailure)
				}
			}
			Spacer()
			Button("Done") {
				dismiss()
			}
			.accessibilityIdentifier(TestForgeConstants.Accessibility.prepareCodeDone)
			if viewModel.phase == .choosing || isFinished {
				Button(viewModel.prepareTitle) {
					viewModel.prepare()
				}
				.keyboardShortcut(.defaultAction)
				.disabled(!viewModel.canPrepare)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.prepareCodeStart)
			}
		}
	}

	private var isFinished: Bool {
		if case .finished = viewModel.phase {
			return true
		}
		return false
	}
}
