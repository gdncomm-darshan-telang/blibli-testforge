import SwiftUI

/// The Tests screen's helpers that open their own sheets (D-191 Run all, D-193 Post to Jira).
struct TestsCompanions {
	let sessionExport: SessionExportViewModel
	let batchPlan: BatchPlanViewModel
	let jiraPost: JiraPostViewModel
	let caseInputs: CaseInputsViewModel
	let verifyChanges: VerifyChangesViewModel
}

/// Observes the sheet models itself, so the Tests screen doesn't redraw for every keystroke in a sheet.
struct TestsSheetsModifier: ViewModifier {
	@ObservedObject var batchPlan: BatchPlanViewModel
	@ObservedObject var jiraPost: JiraPostViewModel

	func body(content: Content) -> some View {
		content
			.sheet(isPresented: isBatchPlanShown) {
				BatchPlanSheetView(viewModel: batchPlan)
			}
			.sheet(isPresented: isJiraPostShown) {
				JiraPostSheetView(viewModel: jiraPost)
			}
	}

	private var isBatchPlanShown: Binding<Bool> {
		Binding(get: { batchPlan.isShown }, set: { isShown in
			if !isShown {
				batchPlan.dismiss()
			}
		})
	}

	private var isJiraPostShown: Binding<Bool> {
		Binding(get: { jiraPost.isShown }, set: { isShown in
			if !isShown {
				jiraPost.dismiss()
			}
		})
	}
}
