import SwiftUI

/// Get Ready › Prerequisites (D-190): what this Mac needs and the one step that fixes each missing piece.
struct PrerequisitesSheetView: View {
	@ObservedObject var viewModel: PrerequisitesViewModel
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			HStack {
				Text("Prerequisites")
					.font(.title2.weight(.semibold))
				Spacer()
				Button {
					viewModel.refresh()
				} label: {
					ActionProgressLabel(title: String(localized: "Check again"), busyTitle: String(localized: "Checking…"), isBusy: viewModel.isRefreshing)
				}
				.disabled(viewModel.isRefreshing)
				.help("Ask Claude Code again for its plugins and MCP servers (takes a few seconds)")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.prerequisitesRefresh)
			}
			content
			HStack {
				Spacer()
				Button("Done") {
					dismiss()
				}
				.keyboardShortcut(.defaultAction)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.prerequisitesDone)
			}
		}
		.padding(TestForgeConstants.Spacing.extraLarge)
		.frame(minWidth: TestForgeConstants.GetReady.prerequisitesWidth, minHeight: TestForgeConstants.GetReady.prerequisitesHeight)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.prerequisitesSheet)
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.state {
			case .loading:
				LoadingStateView(text: "Asking Claude Code…")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .failed(let message):
				ContentUnavailableView("Couldn't check", systemImage: "exclamationmark.triangle", description: Text(message))
			case .loaded(let rows, let checkedText):
				List {
					ForEach(groupTitles(of: rows), id: \.self) { title in
						Section(title) {
							ForEach(rows.filter { $0.groupTitle == title }) { row in
								PrerequisiteRowView(row: row) { howTo in
									viewModel.copy(howTo: howTo)
								}
							}
						}
					}
				}
				Text(checkedText)
					.font(.caption)
					.foregroundStyle(.secondary)
		}
	}

	private func groupTitles(of rows: [PrerequisiteRowModel]) -> [String] {
		rows.reduce(into: [String]()) { titles, row in
			if !titles.contains(row.groupTitle) {
				titles.append(row.groupTitle)
			}
		}
	}
}
