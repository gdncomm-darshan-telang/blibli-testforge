import Foundation

/// Words for the Git sheet, so its views only render.
enum GitControlMapper {
	static func content(for status: GitRepoStatus) -> GitStatusContent {
		GitStatusContent(
			title: status.branch ?? String(localized: "Detached at \(status.sha ?? "?")"),
			subject: [status.sha, status.subject].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
			syncText: syncText(for: status),
			changesText: status.isDirty ? String(localized: "\(status.changedCount) uncommitted change(s)") : String(localized: "No uncommitted changes"),
			fetchedText: status.fetchedAt.map { String(localized: "Last fetched \($0.formatted(.relative(presentation: .named)))") } ?? String(localized: "Never fetched"),
			warning: status.operation.map { String(localized: "\($0.capitalized) is half done. Finish or abort it in a terminal; the app won't switch until then.") },
			files: status.files,
			isBehind: status.behind > 0,
			hasStash: status.stashCount > 0
		)
	}

	static func message(after action: GitAction, status: GitRepoStatus) -> GitMessage {
		var text = status.note ?? ""
		if case .fetch = action {
			text = status.behind > 0 ? String(localized: "Fetched. \(status.branch ?? "This branch") is \(status.behind) commit(s) behind GitHub.") : String(localized: "Fetched. Up to date with GitHub.")
		}
		if status.stashed != nil {
			text += String(localized: " Your changes were stashed; Restore stash brings them back.")
		}
		return GitMessage(text: text, isError: false)
	}

	private static func syncText(for status: GitRepoStatus) -> String {
		guard let upstream = status.upstream else {
			return String(localized: "Not tracking a GitHub branch")
		}
		switch (status.ahead, status.behind) {
			case (0, 0):
				return String(localized: "In step with \(upstream)")
			case (let ahead, 0):
				return String(localized: "\(ahead) commit(s) ahead of \(upstream) — push in a terminal")
			case (0, let behind):
				return String(localized: "\(behind) commit(s) behind \(upstream)")
			case (let ahead, let behind):
				return String(localized: "\(ahead) ahead, \(behind) behind \(upstream) — merge or rebase in a terminal")
		}
	}
}
