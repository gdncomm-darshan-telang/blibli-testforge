import CoreGraphics
import Foundation

enum NetworkConsoleConstants {
	enum Refresh {
		static let tickInterval: Duration = .seconds(2)
		/// Rules come back with every body (about 1 MB live), so they refresh every third tick; any change refreshes at once.
		static let slowTickEvery = 3

		static let callLimit = 200
	}

	enum Traffic {
		static let listWidth: CGFloat = 440
		static let methodWidth: CGFloat = 52
		static let statusWidth: CGFloat = 40
		static let durationWidth: CGFloat = 64
		static let searchFieldWidth: CGFloat = 220
	}

	enum Rules {
		static let listWidth: CGFloat = 520
		static let variantPickerWidth: CGFloat = 170
		static let disabledRuleOpacity: Double = 0.55
	}

	enum Editor {
		static let sheetWidth: CGFloat = 720
		static let sheetHeight: CGFloat = 620
		static let numberFieldWidth: CGFloat = 80
		static let timeShiftListHeight: CGFloat = 140
		static let bodyMinHeight: CGFloat = 240
	}

	enum Scenarios {
		static let nameFieldWidth: CGFloat = 220
		static let menuWidth: CGFloat = 240
	}

	enum Trackers {
		static let listWidth: CGFloat = 520
		static let idsFieldMinWidth: CGFloat = 260
		static let countWidth: CGFloat = 120
		static let payloadMaxHeight: CGFloat = 320
		static let reportFileName = "trackers-validation.md"
	}

	enum Breakpoints {
		static let listWidth: CGFloat = 460
		static let barDividerHeight: CGFloat = 18
	}

	enum Surface {
		static let stripOpacity: Double = 0.5
		static let warningOpacity: Double = 0.08
	}

	enum Badge {
		static let horizontalPadding: CGFloat = 6
		static let verticalPadding: CGFloat = 2
		static let backgroundOpacity: Double = 0.15
	}

	enum Accessibility {
		static let page = "QAW_Network"
		static let healthStrip = "QAW_Network_Health"
		static let mockingToggle = "QAW_Network_MockingToggle"
		static let guardrailsBanner = "QAW_Network_Guardrails"
		static let allOffButton = "QAW_Network_AllOffButton"
		static let resetToPackButton = "QAW_Network_ResetToPackButton"
		static let tabPicker = "QAW_Network_TabPicker"
		static let traffic = "QAW_Network_Traffic"
		static let searchField = "QAW_Network_SearchField"
		static let mockedOnlyToggle = "QAW_Network_MockedOnlyToggle"
		static let callRowPrefix = "QAW_Network_CallRow_"
		static let callDetail = "QAW_Network_CallDetail"
		static let mockCallButton = "QAW_Network_MockCallButton"
		static let copyCurlButton = "QAW_Network_CopyCurlButton"
		static let rules = "QAW_Network_Rules"
		static let ruleRowPrefix = "QAW_Network_RuleRow_"
		static let ruleTogglePrefix = "QAW_Network_RuleToggle_"
		static let variantPickerPrefix = "QAW_Network_VariantPicker_"
		static let variantPreview = "QAW_Network_VariantPreview"
		static let editVariantButton = "QAW_Network_EditVariantButton"
		static let scenariosBar = "QAW_Network_Scenarios"
		static let scenarioNameField = "QAW_Network_ScenarioNameField"
		static let saveScenarioButton = "QAW_Network_SaveScenarioButton"
		static let applyScenarioMenu = "QAW_Network_ApplyScenarioMenu"
		static let deleteScenarioMenu = "QAW_Network_DeleteScenarioMenu"
		static let editorSheet = "QAW_Network_Editor"
		static let editorNameField = "QAW_Network_Editor_NameField"
		static let editorKindPicker = "QAW_Network_Editor_KindPicker"
		static let editorStatusField = "QAW_Network_Editor_StatusField"
		static let editorDelayField = "QAW_Network_Editor_DelayField"
		static let editorFailurePicker = "QAW_Network_Editor_FailurePicker"
		static let editorBody = "QAW_Network_Editor_Body"
		static let editorSaveButton = "QAW_Network_Editor_SaveButton"
		static let editorSaveCopyButton = "QAW_Network_Editor_SaveCopyButton"
		static let editorDeleteButton = "QAW_Network_Editor_DeleteButton"
		static let editorCancelButton = "QAW_Network_Editor_CancelButton"
		static let timeShift = "QAW_Network_Editor_TimeShift"
		static let timeShiftSecondsField = "QAW_Network_Editor_TimeShiftSeconds"
		static let timeShiftButton = "QAW_Network_Editor_TimeShiftButton"
		static let placeholder = "QAW_Network_Placeholder"
		static let trackers = "QAW_Network_Trackers"
		static let trackerIdsField = "QAW_Network_Trackers_IdsField"
		static let trackerAllSessionsToggle = "QAW_Network_Trackers_AllSessionsToggle"
		static let trackerCheckButton = "QAW_Network_Trackers_CheckButton"
		static let trackerContractButton = "QAW_Network_Trackers_ContractButton"
		static let trackerClearContractButton = "QAW_Network_Trackers_ClearContractButton"
		static let trackerCopyReportButton = "QAW_Network_Trackers_CopyReportButton"
		static let trackerSaveReportButton = "QAW_Network_Trackers_SaveReportButton"
		static let trackerRowPrefix = "QAW_Network_TrackerRow_"
		static let trackerFires = "QAW_Network_Trackers_Fires"
		static let trackerFirePrefix = "QAW_Network_TrackerFire_"
		static let breakpoints = "QAW_Network_Breakpoints"
		static let breakpointEndpointField = "QAW_Network_Breakpoints_EndpointField"
		static let breakpointStagePicker = "QAW_Network_Breakpoints_StagePicker"
		static let breakpointOnceToggle = "QAW_Network_Breakpoints_OnceToggle"
		static let breakpointAddButton = "QAW_Network_Breakpoints_AddButton"
		static let breakpointRowPrefix = "QAW_Network_BreakpointRow_"
		static let breakpointRemovePrefix = "QAW_Network_BreakpointRemove_"
		static let bubbleMenu = "QAW_Network_Breakpoints_BubbleMenu"
		static let heldRowPrefix = "QAW_Network_HeldRow_"
		static let heldContinueAllButton = "QAW_Network_Breakpoints_ContinueAllButton"
		static let heldEditor = "QAW_Network_HeldEditor"
		static let heldStatusField = "QAW_Network_HeldEditor_StatusField"
		static let heldBodyEditor = "QAW_Network_HeldEditor_Body"
		static let heldFailurePicker = "QAW_Network_HeldEditor_FailurePicker"
		static let heldFailButton = "QAW_Network_HeldEditor_FailButton"
		static let heldContinueButton = "QAW_Network_HeldEditor_ContinueButton"
		static let replayCallButton = "QAW_Network_ReplayCallButton"
		static let holdCallButton = "QAW_Network_HoldCallButton"
	}
}
