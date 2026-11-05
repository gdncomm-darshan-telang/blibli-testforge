import Foundation

/// Reports › Session report (D-176).
enum ReportsConstants {
	enum Accessibility {
		static let modePicker = "QAW_Reports_ModePicker"
		static let sessionReport = "QAW_SessionReport"
		static let sessionRefresh = "QAW_SessionReport_Refresh"
		static let sessionCopy = "QAW_SessionReport_Copy"
		static let sessionExportMenu = "QAW_SessionReport_ExportMenu"
		static let sessionExportMarkdown = "QAW_SessionReport_ExportMarkdown"
		static let sessionExportConfluence = "QAW_SessionReport_ExportConfluence"
		static let sessionPublish = "QAW_SessionReport_Publish"
		static let sessionPublishConfirm = "QAW_SessionReport_PublishConfirm"
		static let sessionNotice = "QAW_SessionReport_Notice"
		static let batchList = "QAW_Batches_List"
		static let batchRowPrefix = "QAW_Batches_Row_"
		static let batchDetail = "QAW_Batches_Detail"
		static let batchProgress = "QAW_Batches_Progress"
		static let batchReopen = "QAW_Batches_Reopen"
		static let batchEnd = "QAW_Batches_End"
		static let batchPause = "QAW_Batches_Pause"
		static let batchResume = "QAW_Batches_Resume"
		static let batchRemove = "QAW_Batches_Remove"
		static let batchRemoveConfirm = "QAW_Batches_RemoveConfirm"
		static let batchReveal = "QAW_Batches_Reveal"
		static let batchRefresh = "QAW_Batches_Refresh"
		static let batchReport = "QAW_Batches_Report"
		static let batchReplay = "QAW_Batches_Replay"
		static let batchReplayConfirm = "QAW_Batches_ReplayConfirm"
		static let batchComparison = "QAW_Batches_Comparison"
	}
}

enum ReportsMode: String, CaseIterable, Identifiable {
	case session
	case batches
	case runs
	case demos

	var id: String { rawValue }

	var title: String {
		switch self {
			case .session:
				return String(localized: "Session report")
			case .batches:
				return String(localized: "Batches")
			case .runs:
				return String(localized: "Runs by branch")
			case .demos:
				return String(localized: "Demos")
		}
	}
}
