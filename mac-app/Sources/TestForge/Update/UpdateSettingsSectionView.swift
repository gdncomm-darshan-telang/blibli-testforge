import SwiftUI

/// Settings › Project › Updates: status, what is coming, and Check / Update and restart.
struct UpdateSettingsSectionView<ViewModel: UpdatePresenting>: View {
	@ObservedObject var viewModel: ViewModel

	var body: some View {
		Section("Updates") {
			statusRow
			incomingList
			HStack {
				Button(action: viewModel.check) {
					ActionProgressLabel(
						title: String(localized: "Check now"),
						busyTitle: String(localized: "Checking…"),
						isBusy: viewModel.activity == .checking
					)
				}
				.disabled(viewModel.activity.isBusy)
				.accessibilityIdentifier(UpdateConstants.Accessibility.checkButton)
				Button(action: viewModel.update) {
					ActionProgressLabel(
						title: String(localized: "Update and restart"),
						busyTitle: busyTitle,
						isBusy: viewModel.activity == .pulling || viewModel.activity == .building
					)
				}
				.disabled(!viewModel.canUpdate)
				.accessibilityIdentifier(UpdateConstants.Accessibility.updateButton)
			}
			if viewModel.activity == .building {
				Text("Building takes about a minute. TestForge reopens by itself when it is done.")
					.font(.callout)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier(UpdateConstants.Accessibility.progressText)
			}
			if let message = viewModel.message {
				Text(message)
					.font(.callout)
					.foregroundStyle(.red)
					.textSelection(.enabled)
					.accessibilityIdentifier(UpdateConstants.Accessibility.failureText)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(UpdateConstants.Accessibility.section)
	}

	private var busyTitle: String {
		viewModel.activity == .pulling ? String(localized: "Pulling…") : String(localized: "Building…")
	}

	@ViewBuilder
	private var statusRow: some View {
		if let status = viewModel.status {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Label {
					Text(statusText(for: status))
				} icon: {
					Image(systemName: symbolName(for: status))
						.foregroundStyle(symbolColor(for: status))
				}
				.accessibilityIdentifier(UpdateConstants.Accessibility.statusText)
				if let hint = hint(for: status) {
					Text(hint)
						.font(.callout)
						.foregroundStyle(.secondary)
						.accessibilityIdentifier(UpdateConstants.Accessibility.hintText)
				}
			}
		} else {
			Text("Not checked yet.")
				.foregroundStyle(.secondary)
				.accessibilityIdentifier(UpdateConstants.Accessibility.statusText)
		}
	}

	@ViewBuilder
	private var incomingList: some View {
		if let status = viewModel.status, !status.incoming.isEmpty {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				ForEach(Array(status.incoming.enumerated()), id: \.offset) { index, subject in
					Text("• \(subject)")
						.font(.callout)
						.accessibilityIdentifier(UpdateConstants.Accessibility.incomingRowPrefix + String(index))
				}
			}
			.accessibilityElement(children: .contain)
			.accessibilityIdentifier(UpdateConstants.Accessibility.incomingList)
		}
	}

	private func statusText(for status: UpdateStatus) -> String {
		switch status.state {
			case .upToDate:
				return String(localized: "Up to date (\(status.currentCommit)).")
			case .available(let count):
				return String(localized: "\(count) new changes: \(status.currentCommit) → \(status.latestCommit).")
			case .blocked:
				return String(localized: "Can't update this checkout.")
		}
	}

	private func hint(for status: UpdateStatus) -> String? {
		guard case .blocked(let block) = status.state else {
			return nil
		}
		switch block {
			case .notOnTrunk(let branch):
				return String(localized: "This checkout is on \(branch). Updating only works on master: switch with git switch master.")
			case .localChanges:
				return String(localized: "This checkout has uncommitted changes. Commit or stash them, then check again.")
			case .diverged:
				return String(localized: "This checkout has commits master doesn't, so it can't fast-forward. Push or rebase them first.")
		}
	}

	private func symbolName(for status: UpdateStatus) -> String {
		switch status.state {
			case .upToDate:
				return "checkmark.circle.fill"
			case .available:
				return "arrow.down.circle.fill"
			case .blocked:
				return "exclamationmark.triangle.fill"
		}
	}

	private func symbolColor(for status: UpdateStatus) -> Color {
		switch status.state {
			case .upToDate:
				return .green
			case .available:
				return .blue
			case .blocked:
				return .orange
		}
	}
}
