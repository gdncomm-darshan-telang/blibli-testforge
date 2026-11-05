import CoreGraphics

/// Scan › Record macro (D-171).
enum MacroRecorderConstants {
	static let sheetWidth: CGFloat = 520
	static let warningListMaxHeight: CGFloat = 160
	static let bannerCornerRadius: CGFloat = 8
	static let bannerBackgroundOpacity: Double = 0.14
	static let libraryListMinWidth: CGFloat = 280
	static let libraryListIdealWidth: CGFloat = 360
	static let libraryListMaxWidth: CGFloat = 600
	static let libraryDetailMinWidth: CGFloat = 320
	static let rowIconSize: CGFloat = 28

	enum Accessibility {
		static let saveButton = "QAW_RecordMacro_SaveButton"
		static let leftPicker = "QAW_RecordMacro_LeftPicker"
		static let steps = "QAW_RecordMacro_Steps"
		static let stepPrefix = "QAW_RecordMacro_Step_"
		static let stepWarningPrefix = "QAW_RecordMacro_StepWarning_"
		static let stepDeletePrefix = "QAW_RecordMacro_StepDelete_"
		static let stepsEmpty = "QAW_RecordMacro_StepsEmpty"
		static let banner = "QAW_RecordMacro_MissingIdBanner"
		static let bannerText = "QAW_RecordMacro_MissingIdBannerText"
		static let bannerDismiss = "QAW_RecordMacro_MissingIdBannerDismiss"
		static let sheet = "QAW_RecordMacro_Sheet"
		static let sheetName = "QAW_RecordMacro_SheetName"
		static let sheetCase = "QAW_RecordMacro_SheetCase"
		static let sheetModule = "QAW_RecordMacro_SheetModule"
		static let sheetSubmodule = "QAW_RecordMacro_SheetSubmodule"
		static let sheetFreshStart = "QAW_RecordMacro_SheetFreshStart"
		static let sheetWarnings = "QAW_RecordMacro_SheetWarnings"
		static let sheetSave = "QAW_RecordMacro_SheetSave"
		static let sheetCancel = "QAW_RecordMacro_SheetCancel"
		static let startButton = "QAW_RecordMacro_StartButton"
		static let endButton = "QAW_RecordMacro_EndButton"
		static let discardButton = "QAW_RecordMacro_DiscardButton"
		static let discardConfirm = "QAW_RecordMacro_DiscardConfirm"
		static let summary = "QAW_RecordMacro_Summary"
		static let library = "QAW_RecordMacro_Library"
		static let libraryTitle = "QAW_RecordMacro_LibraryTitle"
		static let libraryEmpty = "QAW_RecordMacro_LibraryEmpty"
		static let libraryList = "QAW_RecordMacro_LibraryList"
		static let libraryRowPrefix = "QAW_RecordMacro_LibraryRow_"
		static let libraryRefresh = "QAW_RecordMacro_LibraryRefresh"
		static let macroDetail = "QAW_RecordMacro_MacroDetail"
		static let macroDetailName = "QAW_RecordMacro_MacroDetailName"
		static let macroReplay = "QAW_RecordMacro_MacroReplay"
		static let macroReveal = "QAW_RecordMacro_MacroReveal"
		static let savedNotice = "QAW_RecordMacro_SavedNotice"
		static let savedNoticeDismiss = "QAW_RecordMacro_SavedNoticeDismiss"
		static let macroEditSteps = "QAW_RecordMacro_MacroEditSteps"
		static let stepEditorSheet = "QAW_StepEditor_Sheet"
		static let stepEditorList = "QAW_StepEditor_List"
		static let stepEditorRowPrefix = "QAW_StepEditor_Row_"
		static let stepEditorRemovePrefix = "QAW_StepEditor_Remove_"
		static let stepEditorTimeoutPrefix = "QAW_StepEditor_Timeout_"
		static let stepEditorOptionalPrefix = "QAW_StepEditor_Optional_"
		static let stepEditorTextPrefix = "QAW_StepEditor_Text_"
		static let stepEditorSave = "QAW_StepEditor_Save"
		static let stepEditorRevert = "QAW_StepEditor_Revert"
		static let stepEditorCancel = "QAW_StepEditor_Cancel"
		static let stepEditorStatus = "QAW_StepEditor_Status"
	}

	enum StepEditor {
		static let width: CGFloat = 640
		static let listHeight: CGFloat = 420
		static let numberFieldWidth: CGFloat = 56
		static let timeoutRange: ClosedRange<Double> = 0.5...120
	}
}
