import SwiftUI

/// Board C2: plain-words readiness checks with overall progress; raw commands go to the console.
struct GetReadySectionView: View {
	@ObservedObject var viewModel: GetReadySectionViewModel
	let companions: GetReadyCompanions

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
				GetReadyToolsBarView(companions: companions)
				stateContent
			}
			.frame(maxWidth: TestForgeConstants.GetReady.contentMaxWidth, alignment: .leading)
			.padding(TestForgeConstants.Spacing.extraLarge)
			.frame(maxWidth: .infinity)
		}
		.confirmationDialog(confirmationTitle, isPresented: isConfirmationPresented, presenting: viewModel.pendingFix) { pendingFix in
			Button {
				viewModel.confirmPendingFix()
			} label: {
				Text(pendingFix.action.title)
			}
			Button("Cancel", role: .cancel) {
				viewModel.pendingFix = nil
			}
		} message: { pendingFix in
			if let confirmation = pendingFix.action.confirmation {
				Text(confirmation)
			}
		}
		.getReadySheets(companions: companions)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.getReady)
		.tutorialAnchor(.getReadyChecks)
	}

	@ViewBuilder
	private var stateContent: some View {
		switch viewModel.state {
			case .checking(let content), .ready(let content), .needsAttention(let content):
				GetReadyHeaderView(headline: content.headline, progressFraction: content.progressFraction)
				rowList(rows: content.rows)
		}
	}

	private func rowList(rows: [ReadinessRowModel]) -> some View {
		VStack(spacing: 0) {
			ForEach(rows) { row in
				ReadinessRowView(row: row, fixState: viewModel.fixState(forRowId: row.id)) {
					viewModel.requestFix(for: row)
				}
				Divider()
			}
		}
	}

	private var confirmationTitle: Text {
		Text("Run this fix?")
	}

	private var isConfirmationPresented: Binding<Bool> {
		Binding {
			viewModel.pendingFix != nil
		} set: { isPresented in
			if !isPresented {
				viewModel.pendingFix = nil
			}
		}
	}
}
