import CoreGraphics

/// D-199: Prepare code, the run queue, test logins and run popups, moved here from the web UI.
extension TestForgeConstants.Accessibility {
	static let getReadyPrepareCodeButton = "QAW_GetReady_PrepareCodeButton"
	static let getReadyRunQueueButton = "QAW_GetReady_RunQueueButton"

	static let prepareCodeSheet = "QAW_PrepareCode_Sheet"
	static let prepareCodeSource = "QAW_PrepareCode_Source"
	static let prepareCodeRepository = "QAW_PrepareCode_Repository"
	static let prepareCodeBranchField = "QAW_PrepareCode_BranchField"
	static let prepareCodeBranchPrefix = "QAW_PrepareCode_Branch_"
	static let prepareCodeBranchNote = "QAW_PrepareCode_BranchNote"
	static let prepareCodeAskGitHub = "QAW_PrepareCode_AskGitHub"
	static let prepareCodeLocalNote = "QAW_PrepareCode_LocalNote"
	static let prepareCodeCurrent = "QAW_PrepareCode_Current"
	static let prepareCodeStart = "QAW_PrepareCode_Start"
	static let prepareCodeCancel = "QAW_PrepareCode_Cancel"
	static let prepareCodeDone = "QAW_PrepareCode_Done"
	static let prepareCodeProgressPrefix = "QAW_PrepareCode_Progress_"
	static let prepareCodeResult = "QAW_PrepareCode_Result"

	static let runQueueSheet = "QAW_RunQueue_Sheet"
	static let runQueueDevice = "QAW_RunQueue_Device"
	static let runQueueEmpty = "QAW_RunQueue_Empty"
	static let runQueueClearFinished = "QAW_RunQueue_ClearFinished"
	static let runQueueDone = "QAW_RunQueue_Done"
	static let runQueueRowPrefix = "QAW_RunQueue_Row_"
	static let runQueueMoveUpPrefix = "QAW_RunQueue_MoveUp_"
	static let runQueueMoveDownPrefix = "QAW_RunQueue_MoveDown_"
	static let runQueueCancelPrefix = "QAW_RunQueue_Cancel_"
	static let runQueueRetryPrefix = "QAW_RunQueue_Retry_"
	static let runQueueMessage = "QAW_RunQueue_Message"

	static let loginsSettings = "QAW_Logins_Settings"
	static let loginsRowPrefix = "QAW_Logins_Row_"
	static let loginsRemovePrefix = "QAW_Logins_Remove_"
	static let loginsEnvironment = "QAW_Logins_Environment"
	static let loginsProfile = "QAW_Logins_Profile"
	static let loginsEmail = "QAW_Logins_Email"
	static let loginsPassword = "QAW_Logins_Password"
	static let loginsOtp = "QAW_Logins_Otp"
	static let loginsSave = "QAW_Logins_Save"
	static let loginsMessage = "QAW_Logins_Message"
	static let loginsMailOtp = "QAW_Logins_MailOtp"
	static let loginsMailLink = "QAW_Logins_MailLink"
	static let loginsMailUnlink = "QAW_Logins_MailUnlink"
	static let loginsMailCode = "QAW_Logins_MailCode"

	static let runPromptSheet = "QAW_RunPrompt_Sheet"
	static let runPromptInput = "QAW_RunPrompt_Input"
	static let runPromptDone = "QAW_RunPrompt_Done"
	static let runPromptSkip = "QAW_RunPrompt_Skip"
	static let runPromptStop = "QAW_RunPrompt_Stop"
	static let runPromptShowSimulator = "QAW_RunPrompt_ShowSimulator"
	static let runPromptMessage = "QAW_RunPrompt_Message"
}

extension TestForgeConstants.GetReady {
	static let prepareCodeWidth: CGFloat = 620
	static let prepareCodeHeight: CGFloat = 560
	static let runQueueWidth: CGFloat = 600
	static let runQueueHeight: CGFloat = 480
	static let runPromptWidth: CGFloat = 460
	static let branchListMaxHeight: CGFloat = 220
}
