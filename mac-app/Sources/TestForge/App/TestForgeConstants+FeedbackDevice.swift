import Foundation

/// D-213: progress and result lines beside the Network, Simulator, Claude, Remote Control and Build controls that started the work.
extension TestForgeConstants.Accessibility {
		static let buildStopFailure = "QAW_Build_StopFailure"
		static let buildRefreshProgress = "QAW_Build_RefreshProgress"
		static let networkResetFailure = "QAW_Network_ResetFailure"
		static let networkScenarioFailure = "QAW_Network_ScenarioFailure"
		static let networkScenarioProgress = "QAW_Network_ScenarioProgress"
		static let networkCallActionResult = "QAW_Network_CallActionResult"
		static let networkBreakpointRemovingPrefix = "QAW_Network_BreakpointRemoving_"
		static let networkBreakpointFailure = "QAW_Network_BreakpointFailure"
		static let networkBubbleProgress = "QAW_Network_BubbleProgress"
		static let networkTrackerReportProgress = "QAW_Network_TrackerReportProgress"
		static let networkTrackerReportMenu = "QAW_Network_TrackerReportMenu"
		static let networkTrackerReportResult = "QAW_Network_TrackerReportResult"
		static let simulatorCardProgressPrefix = "QAW_SimulatorControl_CardProgress_"
		static let simulatorCardResultPrefix = "QAW_SimulatorControl_CardResult_"
		static let simulatorTestDeviceError = "QAW_SimulatorControl_TestDeviceError"
		static let claudeStopFailure = "QAW_Claude_StopFailure"
		static let claudeApprovalFailure = "QAW_Claude_ApprovalFailure"
		static let claudeQuestionFailure = "QAW_Claude_QuestionFailure"
		static let remoteControlFailure = "QAW_RemoteControl_Failure"
}
