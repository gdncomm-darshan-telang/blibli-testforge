import SwiftUI

struct BranchMatchRowView: View {
	let branch: CodeBranch
	let isSelected: Bool
	let onChoose: () -> Void

	var body: some View {
		Button(action: onChoose) {
			HStack(alignment: .firstTextBaseline, spacing: TestForgeConstants.Spacing.medium) {
				Image(systemName: isSelected ? "checkmark.circle.fill" : "arrow.triangle.branch")
					.foregroundStyle(isSelected ? Color.accentColor : .secondary)
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
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.prepareCodeBranchPrefix + branch.name)
	}

	private var detail: String {
		var parts = [branch.sha, branch.subject]
		if let committedAt = branch.committedAt {
			parts.append(committedAt.formatted(.relative(presentation: .named)))
		}
		if branch.isNewOnGitHub {
			parts.append(String(localized: "new on GitHub"))
		} else if !branch.isOnGitHub {
			parts.append(String(localized: "only on this Mac"))
		}
		return parts.filter { !$0.isEmpty }.joined(separator: " · ")
	}
}
