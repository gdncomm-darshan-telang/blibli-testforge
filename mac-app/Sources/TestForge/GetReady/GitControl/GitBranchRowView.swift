import SwiftUI

struct GitBranchRowView: View {
	let branch: CodeBranch
	let isCurrent: Bool
	let isDisabled: Bool
	let onSwitch: () -> Void

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
			Image(systemName: isCurrent ? "checkmark.circle.fill" : "arrow.triangle.branch")
				.foregroundStyle(isCurrent ? Color.accentColor : .secondary)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text(branch.name)
					.font(.body.monospaced())
				Text(detail)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			Spacer()
			if isCurrent {
				Text("Current")
					.font(.caption)
					.foregroundStyle(.secondary)
			} else {
				Button("Switch", action: onSwitch)
					.disabled(isDisabled)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.gitSwitchPrefix + branch.name)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.gitBranchPrefix + branch.name)
	}

	private var detail: String {
		var parts = [branch.sha, branch.subject]
		if let committedAt = branch.committedAt {
			parts.append(committedAt.formatted(.relative(presentation: .named)))
		}
		if !branch.isLocal {
			parts.append(String(localized: "GitHub only — switching creates a local branch"))
		} else if !branch.isOnGitHub {
			parts.append(String(localized: "only on this Mac"))
		}
		return parts.filter { !$0.isEmpty }.joined(separator: " · ")
	}
}
