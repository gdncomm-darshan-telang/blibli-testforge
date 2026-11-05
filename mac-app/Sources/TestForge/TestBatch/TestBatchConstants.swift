import Foundation

/// Reopening an ended Test Batch (D-184); pausing and resuming one (D-212).
extension TestForgeConstants.TestBatch {
		/// Newest ended batches offered under Reopen Test Batch.
		static let reopenMenuLimit = 8
}

extension TestForgeConstants.Accessibility {
		static let testBatchReopenMenu = "QAW_TestBatch_ReopenMenu"
		static let testBatchReopenItemPrefix = "QAW_TestBatch_ReopenItem_"
		static let testBatchReopenConfirmButton = "QAW_TestBatch_ReopenConfirm"
		static let testBatchPauseItem = "QAW_TestBatch_PauseItem"
		static let testBatchStartAnotherItem = "QAW_TestBatch_StartAnotherItem"
		static let testBatchStartNote = "QAW_TestBatch_StartNote"
		static let testBatchResumeMenu = "QAW_TestBatch_ResumeMenu"
		static let testBatchResumeItemPrefix = "QAW_TestBatch_ResumeItem_"
		static let testBatchPausedList = "QAW_TestBatch_PausedList"
		static let testBatchSheetResumePrefix = "QAW_TestBatch_SheetResume_"
}
