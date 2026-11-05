import CoreGraphics
import Foundation
import SwiftUI

enum TestForgeConstants {
	enum Window {
		static let mainWindowId = "main"
		static let measureWindowId = "measure"
		static let proofViewerWindowId = "proof"
		/// Tests panes (862) plus the sidebar counted twice: on macOS 26 the detail column runs under the sidebar and is inset by it.
		static let minWidth: CGFloat = 1240
		static let narrowestWidth: CGFloat = 480

		static let minHeight: CGFloat = 560
		static let sidebarMinWidth: CGFloat = 180
		static let sectionMinHeight: CGFloat = 360
		static let sectionIdealHeight: CGFloat = 640
	}

	enum Spacing {
		static let small: CGFloat = 4
		static let medium: CGFloat = 8
		static let large: CGFloat = 16
		static let extraLarge: CGFloat = 24
	}

	enum GetReady {
		static let rowIconSize: CGFloat = 18
		static let contentMaxWidth: CGFloat = 720
	}

	enum Console {
		static let minHeight: CGFloat = 140
		static let idealHeight: CGFloat = 220
		/// Without a cap the split gave every extra point of a taller window to the console.
		static let maxHeight: CGFloat = 420

		static let sourceTagWidth: CGFloat = 56
		static let searchFieldWidth: CGFloat = 200
	}

	enum Tests {
		static let listWidth: CGFloat = 340
		static let listMinWidth: CGFloat = 240
		static let listMaxWidth: CGFloat = 720
		static let detailMinWidth: CGFloat = 280
		static let inspectorWidth: CGFloat = 280
		static let inspectorMinWidth: CGFloat = 220
		static let inspectorMaxWidth: CGFloat = 560
		static let stepIconSize: CGFloat = 14
		static let loadSheetWidth: CGFloat = 480
		static let badgeVerticalPadding: CGFloat = 2
		static let badgeBackgroundOpacity: Double = 0.12
	}

	enum Scan {
		static let screenListWidth: CGFloat = 300
		static let lastScanListMaxHeight: CGFloat = 260
		static let identifierChipMinWidth: CGFloat = 180
		static let chipCornerRadius: CGFloat = 4
	}

	/// Results panes (260 + 300 + 320) fit the 1 240-pt window minimum, like Tests.
	enum Results {
		static let runListWidth: CGFloat = 260
		static let detailMinWidth: CGFloat = 300
		static let inspectorWidth: CGFloat = 320
		static let tileMinWidth: CGFloat = 64
		static let tileCornerRadius: CGFloat = 8
		static let tileBackgroundOpacity: Double = 0.08
		static let screenshotHeight: CGFloat = 220
		static let stepsMaxHeight: CGFloat = 240
		static let overrideSheetWidth: CGFloat = 440
		static let reasonLineRange = 3...6
		static let minimumReasonLength = 5
	}

	enum Reports {
		static let branchListWidth: CGFloat = 260
		static let contentMaxWidth: CGFloat = 900
		static let verdictColumnWidth: CGFloat = 150
		static let changeColumnWidth: CGFloat = 120
		static let pickerMaxWidth: CGFloat = 360
	}

	enum Simulator {
		static let bundleIdentifier = "com.apple.iphonesimulator"
		static let desktopSwitchTimeout: TimeInterval = 3
		static let tileTimeout: TimeInterval = 6
		static let desktopPollNanoseconds: UInt64 = 100_000_000
		static let clickStepNanoseconds: UInt64 = 100_000_000
	}

	enum Overlay {
		static let outlineLineWidth: CGFloat = 3
		static let outlineCornerRadius: CGFloat = 4
		static let badgeHeight: CGFloat = 20
		static let badgeMaxWidth: CGFloat = 260
		static let trackingInterval = Duration.milliseconds(400)

		/// The server lets the lease lapse after 90 s, so renewing every minute keeps it alive with room to spare.
		static let leaseRenewal = Duration.seconds(60)
	}

	enum FlowMap {
		/// Jaccard overlap of normalized identifiers that makes two reads the same screen.
		static let matchThreshold = 0.55

		/// Same nav title lowers the bar: a list screen keeps its title while its rows (and identifiers) change.
		static let sameTitleMatchThreshold = 0.3

		static let titleBandFraction: CGFloat = 0.18
		static let titleCentreFraction: CGFloat = 0.3
		static let titleMaximumLength = 32
		static let identifierParentDepth = 3
		static let identifierParentAreaRatio: CGFloat = 6
		static let minimumPrefixCount = 3
		static let maximumReads = 5
		static let settleNanoseconds: UInt64 = 600_000_000
		static let swipeThreshold: CGFloat = 12
		static let treeWidth: CGFloat = 360
		static let thumbnailMaxHeight: CGFloat = 420
		static let thumbnailCornerRadius: CGFloat = 8
	}

	enum MeasureSnapshot {
		/// Fixed colours, not system ones: the exported PNG must look the same in light and dark mode.
		static let elementColor = Color(red: 0.0, green: 0.48, blue: 1.0)

		static let gapColor = Color(red: 0.91, green: 0.12, blue: 0.39)
		static let pinColor = Color(red: 0.96, green: 0.45, blue: 0.0)

		static let elementLineWidth: CGFloat = 1.5
		static let gapLineWidth: CGFloat = 1
		static let labelFontSize: CGFloat = 10
		static let pinSize: CGFloat = 20
		static let pinFontSize: CGFloat = 11
		static let pinBorderWidth: CGFloat = 1.5
		static let titleFontSize: CGFloat = 13
		static let noteFontSize: CGFloat = 12
		static let footnoteFontSize: CGFloat = 10
		static let previewWidth: CGFloat = 520
		static let previewHeight: CGFloat = 520
		static let maximumPreviewScale: CGFloat = 2
		static let previewBackgroundOpacity: Double = 0.08
		static let notesWidth: CGFloat = 320

		/// Room kept around the selected view's parent so the spacing lines have context.
		static let cropMargin: CGFloat = 16
	}

	enum ProofViewer {
		static let windowMinWidth: CGFloat = 560
		static let windowMinHeight: CGFloat = 600
		static let zoomStep: CGFloat = 1.25
		static let minimumZoom: CGFloat = 0.05
		static let maximumZoom: CGFloat = 8

		/// Above this zoom, pixels are drawn as blocks so a 1-pt misalignment stays visible instead of being smoothed away.
		static let pixelatedZoom: CGFloat = 2

		static let controlBarHeight: CGFloat = 40
		static let barDividerHeight: CGFloat = 18
		static let zoomTextWidth: CGFloat = 52
		static let playButtonWidth: CGFloat = 18
		static let stripHeight: CGFloat = 88
		static let thumbnailWidth: CGFloat = 40
		static let thumbnailHeight: CGFloat = 72
		static let thumbnailCornerRadius: CGFloat = 4
		static let selectionBorderWidth: CGFloat = 2
		static let videoTileOpacity: Double = 0.08
		static let playbackRates: [Float] = [0.25, 0.5, 1, 1.5, 2]
		static let seekTimescale: Int32 = 600
		static let timeUpdateSeconds: Double = 0.1
		static let endTolerance: Double = 0.05
		static let minimumSliderRange: Double = 0.01
		static let magnificationTolerance: CGFloat = 0.001
	}

	enum SimulatorControl {
		static let resultLineLimit = 4
		static let contentMaxWidth: CGFloat = 1100
		static let cardMinWidth: CGFloat = 380
		static let cardCornerRadius: CGFloat = 12
		static let cardBorderOpacity: Double = 0.12
		static let headerIconSize: CGFloat = 26
		static let headerIconCornerRadius: CGFloat = 7
		static let headerIconOpacity: Double = 0.15
		static let deviceIconSize: CGFloat = 64
		static let deviceSymbolSize: CGFloat = 32
		static let deviceIconCornerRadius: CGFloat = 14
		static let stateDotSize: CGFloat = 7
		static let stateBadgeOpacity: Double = 0.14
		static let deeplinkListMaxHeight: CGFloat = 180
		static let deeplinkRecentLimit = 8
		static let deeplinkMatchDelayMilliseconds = 300
	}

	enum Build {
		static let logLineLimit = 200
		static let logHeight: CGFloat = 180
		static let resultLineLimit = 4
	}

	enum TestBatch {
		static let sheetWidth: CGFloat = 460
	}

	enum Demo {
		static let bannerTintOpacity: Double = 0.12
	}

	enum Measure {
		static let trackpadZoomRate: CGFloat = 0.01
		static let wheelZoomRate: CGFloat = 0.1
		/// The small end of the app's spacing scale, as raw values (D-123).
		static let spacingScale: [CGFloat] = [0, 1, 2, 4]

		/// Above the small end every spacing token (8, 12, 16, 24, 32) and every sum of them (20, 28…) is a multiple of 4.
		static let largeSpacingStep: CGFloat = 4

		/// A pixel this far from the text's background (largest channel difference) counts as ink.
		static let inkThreshold = 48

		static let windowMinWidth: CGFloat = 900
		static let windowMinHeight: CGFloat = 640
		static let canvasMinWidth: CGFloat = 420
		static let detailWidth: CGFloat = 380
		static let zoomSliderWidth: CGFloat = 120
		static let zoomLabelWidth: CGFloat = 44
		static let boxOpacity: Double = 0.45
		static let layerBoxOpacity: Double = 0.7
		static let boxLineWidth: CGFloat = 0.5
		static let selectedLineWidth: CGFloat = 2
		static let gapLineWidth: CGFloat = 1.5
		static let visibleLineWidth: CGFloat = 1.5
		static let visibleDash: [CGFloat] = [5, 3]
		static let hoveredLineWidth: CGFloat = 1.5
	}

	enum Advanced {
		static let pickerMaxWidth: CGFloat = 420
		static let ruleListWidth: CGFloat = 460
		static let macroListWidth: CGFloat = 340
		static let formWidth: CGFloat = 340
		static let historyHeight: CGFloat = 160
		static let variantPickerWidth: CGFloat = 150
		static let methodWidth: CGFloat = 48
		static let statusWidth: CGFloat = 40
		static let callListWidth: CGFloat = 360
		static let disabledRuleOpacity: Double = 0.6
	}

	enum Settings {
		static let width: CGFloat = 520
		static let minHeight: CGFloat = 300
	}

	enum Accessibility {
		static let window = "QAW_Window"
		static let sidebar = "QAW_Sidebar"
		static let sidebarRowPrefix = "QAW_Sidebar_"
		static let connectionStatus = "QAW_Toolbar_ConnectionStatus"
		static let reconnectButton = "QAW_Toolbar_ReconnectButton"
		static let consoleToggleButton = "QAW_Toolbar_ConsoleToggle"
		static let emptyState = "QAW_EmptyState"
		static let getReady = "QAW_GetReady"
		static let getReadyHeader = "QAW_GetReady_Header"
		static let readinessRowPrefix = "QAW_GetReady_Row_"
		static let fixButtonPrefix = "QAW_GetReady_FixButton_"
		static let console = "QAW_Console"
		static let consoleToolbar = "QAW_Console_Toolbar"
		static let consoleFilter = "QAW_Console_Filter"
		static let consoleSearch = "QAW_Console_Search"
		static let consoleCopy = "QAW_Console_CopyButton"
		static let consoleClear = "QAW_Console_ClearButton"
		static let consoleLine = "QAW_Console_Line"
		static let tests = "QAW_Tests"
		static let testsHeader = "QAW_Tests_Header"
		static let testsLoadButton = "QAW_Tests_LoadButton"
		static let testsExportSessionButton = "QAW_Tests_ExportSessionButton"
		static let testsFilterBar = "QAW_Tests_FilterBar"
		static let testsFilter = "QAW_Tests_Filter"
		static let testsList = "QAW_Tests_List"
		static let testsRowPrefix = "QAW_Tests_Row_"
		static let testsDetail = "QAW_Tests_Detail"
		static let testsReplayButton = "QAW_Tests_ReplayButton"
		static let testsRunClaudeButton = "QAW_Tests_RunClaudeButton"
		static let testsInspector = "QAW_Tests_Inspector"
		static let testsInspectorToggle = "QAW_Tests_InspectorToggle"
		static let testsStopButton = "QAW_Tests_StopButton"
		static let testsShowClaudeSessionButton = "QAW_Tests_ShowClaudeSession"
		static let testsRunModelPrefix = "QAW_Tests_RunModel_"
		static let testsStepRowPrefix = "QAW_Tests_Step_"
		static let verdictBadge = "QAW_Tests_VerdictBadge"
		static let loadSheet = "QAW_Tests_LoadSheet"
		static let loadSheetField = "QAW_Tests_LoadSheet_Source"
		static let loadSheetConfirm = "QAW_Tests_LoadSheet_LoadButton"
		static let loadSheetCancel = "QAW_Tests_LoadSheet_CancelButton"
		static let scan = "QAW_Scan"
		static let scanIdle = "QAW_Scan_Idle"
		static let scanHeader = "QAW_Scan_Header"
		static let scanStartButton = "QAW_Scan_StartButton"
		static let scanStopButton = "QAW_Scan_StopButton"
		static let scanShowSimulatorButton = "QAW_Scan_ShowSimulatorButton"
		static let scanRevealButton = "QAW_Scan_RevealButton"
		static let scanCurrentScreen = "QAW_Scan_CurrentScreen"
		static let scanMarkBar = "QAW_Scan_MarkBar"
		static let scanNameField = "QAW_Scan_NameField"
		static let scanMarkButton = "QAW_Scan_MarkButton"
		static let scanSkipButton = "QAW_Scan_SkipButton"
		static let scanScreenList = "QAW_Scan_ScreenList"
		static let scanScreenRowPrefix = "QAW_Scan_Screen_"
		static let results = "QAW_Results"
		static let resultsRunList = "QAW_Results_RunList"
		static let resultsRunRowPrefix = "QAW_Results_Run_"
		static let resultsRunDetail = "QAW_Results_RunDetail"
		static let resultsRunHeader = "QAW_Results_RunHeader"
		static let resultsTilePrefix = "QAW_Results_Tile_"
		static let resultsRerunFailedButton = "QAW_Results_RerunFailedButton"
		static let resultsExportButton = "QAW_Results_ExportButton"
		static let resultsCopyButton = "QAW_Results_CopyButton"
		static let resultsCaseList = "QAW_Results_CaseList"
		static let resultsCaseRowPrefix = "QAW_Results_Case_"
		static let resultsInspector = "QAW_Results_Inspector"
		static let resultsReviewBar = "QAW_Results_ReviewBar"
		static let resultsAcceptButton = "QAW_Results_AcceptButton"
		static let resultsOverrideButton = "QAW_Results_OverrideButton"
		static let resultsNeedsRerunButton = "QAW_Results_NeedsRerunButton"
		static let resultsScreenshots = "QAW_Results_Screenshots"
		static let resultsNote = "QAW_Results_Note"
		static let overrideSheet = "QAW_Results_OverrideSheet"
		static let overrideVerdictPicker = "QAW_Results_OverrideSheet_Verdict"
		static let overrideReasonField = "QAW_Results_OverrideSheet_Reason"
		static let overrideSaveButton = "QAW_Results_OverrideSheet_SaveButton"
		static let overrideCancelButton = "QAW_Results_OverrideSheet_CancelButton"
		static let reports = "QAW_Reports"
		static let reportsBranchList = "QAW_Reports_BranchList"
		static let reportsBranchRowPrefix = "QAW_Reports_Branch_"
		static let reportsPickerBar = "QAW_Reports_PickerBar"
		static let reportsRunPicker = "QAW_Reports_RunPicker"
		static let reportsComparePicker = "QAW_Reports_ComparePicker"
		static let reportsComparison = "QAW_Reports_Comparison"
		static let reportsComparisonRowPrefix = "QAW_Reports_Compare_"
		static let reportsPreview = "QAW_Reports_Preview"
		static let reportsExportButton = "QAW_Reports_ExportButton"
		static let reportsCopyButton = "QAW_Reports_CopyButton"
		static let reportsPublishButton = "QAW_Reports_PublishButton"
		static let menuBar = "QAW_MenuBar"
		static let menuBarLabel = "QAW_MenuBar_Label"
		static let menuBarStatus = "QAW_MenuBar_Status"
		static let menuBarStop = "QAW_MenuBar_StopButton"
		static let menuBarContinue = "QAW_MenuBar_ContinueButton"
		static let menuBarOpen = "QAW_MenuBar_OpenButton"
		static let menuBarQuit = "QAW_MenuBar_QuitButton"
		static let settingsMenuBarToggle = "QAW_Settings_MenuBarToggle"
		static let settingsNotifyToggle = "QAW_Settings_NotifyToggle"
		static let settings = "QAW_Settings"
		static let settingsTabPrefix = "QAW_Settings_Tab_"
		static let settingsProject = "QAW_Settings_Project"
		static let settingsGeneral = "QAW_Settings_General"
		static let settingsAppearance = "QAW_Settings_Appearance"
		static let settingsOutlineToggle = "QAW_Settings_OutlineToggle"
		static let settingsExplainLanguage = "QAW_Settings_ExplainLanguage"
		static let simulatorToolbar = "QAW_Toolbar_Simulator"
		static let measureButton = "QAW_Toolbar_MeasureButton"
		static let outlineToggle = "QAW_Toolbar_OutlineToggle"
		static let stepOutline = "QAW_StepOutline"
		static let stepOutlineBadge = "QAW_StepOutline_Badge"
		static let measure = "QAW_Measure"
		static let measureRefreshButton = "QAW_Measure_RefreshButton"
		static let measureCanvas = "QAW_Measure_Canvas"
		static let measureElementPrefix = "QAW_Measure_Element_"
		static let measureDetail = "QAW_Measure_Detail"
		static let measureGlyphGaps = "QAW_Measure_GlyphGaps"
		static let measureSnapshotButton = "QAW_Measure_SnapshotButton"
		static let measureSnapshotSheet = "QAW_MeasureSnapshot"
		static let measureSnapshotImage = "QAW_MeasureSnapshot_Image"
		static let measureSnapshotPinPrefix = "QAW_MeasureSnapshot_Pin_"
		static let measureSnapshotNotePrefix = "QAW_MeasureSnapshot_Note_"
		static let measureSnapshotShowInFinder = "QAW_Measure_Snapshot_ShowInFinder"
		static let measureSnapshotSave = "QAW_MeasureSnapshot_Save"
		static let measureSnapshotCopy = "QAW_MeasureSnapshot_Copy"
		static let measureSnapshotCancel = "QAW_MeasureSnapshot_Cancel"
		static let measureZoomBar = "QAW_Measure_ZoomBar"
		static let measureZoomInButton = "QAW_Measure_ZoomInButton"
		static let measureZoomOutButton = "QAW_Measure_ZoomOutButton"
		static let measureZoomFitButton = "QAW_Measure_ZoomFitButton"
		static let measureZoomSlider = "QAW_Measure_ZoomSlider"
		static let measureCopyButton = "QAW_Measure_CopyButton"
		static let measureVisibleContainer = "QAW_Measure_VisibleContainer"
		static let measureVisibleSection = "QAW_Measure_VisibleSection"
		static let measureParentsSection = "QAW_Measure_ParentsSection"
		static let measureComparisonSection = "QAW_Measure_ComparisonSection"
		static let measureHoveredBox = "QAW_Measure_HoveredBox"
		static let measureLayerBordersToggle = "QAW_Measure_LayerBordersToggle"
		static let tutorialHelpButton = "QAW_Tutorial_HelpButton"
		static let tutorialDemoItem = "QAW_Tutorial_DemoItem"
		static let tutorialDemoStartButton = "QAW_Tutorial_DemoStartButton"
		static let demoBanner = "QAW_Demo_Banner"
		static let build = "QAW_Build"
		static let buildStatus = "QAW_Build_Status"
		static let buildQAState = "QAW_Build_QAState"
		static let buildStartButton = "QAW_Build_Start"
		static let buildConfirmButton = "QAW_Build_Confirm"
		static let buildStopButton = "QAW_Build_Stop"
		static let buildRefreshButton = "QAW_Build_Refresh"
		static let buildLog = "QAW_Build_Log"
		static let buildXcodeInfo = "QAW_Build_XcodeInfo"
		static let buildOpenWorkspaceButton = "QAW_Build_OpenWorkspace"
		static let buildInstallForTestingButton = "QAW_Build_InstallForTesting"
		static let buildInstallConfirmButton = "QAW_Build_InstallConfirm"
		static let buildLaunchSourcePicker = "QAW_Build_LaunchSource"
		static let buildInstallLaunchButton = "QAW_Build_InstallLaunch"
		static let buildPackageResetButton = "QAW_Build_PackageReset"
		static let buildPackageResetConfirmButton = "QAW_Build_PackageResetConfirm"
		static let buildRunnerStopButton = "QAW_Build_RunnerStop"
		static let testBatchPill = "QAW_TestBatch_Pill"
		static let testBatchStartItem = "QAW_TestBatch_StartItem"
		static let testBatchEndItem = "QAW_TestBatch_EndItem"
		static let testBatchRevealItem = "QAW_TestBatch_RevealItem"
		static let testBatchChooseFolderItem = "QAW_TestBatch_ChooseFolderItem"
		static let testBatchEndConfirmButton = "QAW_TestBatch_EndConfirm"
		static let testBatchStartSheet = "QAW_TestBatch_StartSheet"
		static let testBatchNameField = "QAW_TestBatch_Name"
		static let testBatchStartButton = "QAW_TestBatch_Start"
		static let testBatchCancelButton = "QAW_TestBatch_Cancel"
		static let resultsVideos = "QAW_Results_Videos"
		static let resultsShowInFinderButton = "QAW_Results_ShowInFinder"
		static let scanModePicker = "QAW_Scan_ModePicker"
		static let flowMap = "QAW_FlowMap"
		static let flowMapHeader = "QAW_FlowMap_Header"
		static let flowMapTree = "QAW_FlowMap_Tree"
		static let flowMapNodePrefix = "QAW_FlowMap_Node_"
		static let flowMapDetail = "QAW_FlowMap_Detail"
		static let flowMapNameField = "QAW_FlowMap_NameField"
		static let flowMapEdgePrefix = "QAW_FlowMap_Edge_"
		static let flowMapEmpty = "QAW_FlowMap_Empty"
		static let proofViewer = "QAW_ProofViewer"
		static let proofViewerImage = "QAW_ProofViewer_Image"
		static let proofViewerVideo = "QAW_ProofViewer_Video"
		static let proofViewerPlayer = "QAW_ProofViewer_Player"
		static let proofViewerZoomBar = "QAW_ProofViewer_ZoomBar"
		static let proofViewerZoomIn = "QAW_ProofViewer_ZoomIn"
		static let proofViewerZoomOut = "QAW_ProofViewer_ZoomOut"
		static let proofViewerFit = "QAW_ProofViewer_Fit"
		static let proofViewerActualSize = "QAW_ProofViewer_ActualSize"
		static let proofViewerPlaybackBar = "QAW_ProofViewer_PlaybackBar"
		static let proofViewerPlay = "QAW_ProofViewer_Play"
		static let proofViewerStop = "QAW_ProofViewer_Stop"
		static let proofViewerFrameBack = "QAW_ProofViewer_FrameBack"
		static let proofViewerFrameForward = "QAW_ProofViewer_FrameForward"
		static let proofViewerSpeed = "QAW_ProofViewer_Speed"
		static let proofViewerScrubber = "QAW_ProofViewer_Scrubber"
		static let proofViewerPrevious = "QAW_ProofViewer_Previous"
		static let proofViewerNext = "QAW_ProofViewer_Next"
		static let proofViewerStrip = "QAW_ProofViewer_Strip"
		static let simulatorTestDeviceBadge = "QAW_SimulatorControl_TestDeviceBadge"
		static let simulatorUseForTestsButton = "QAW_SimulatorControl_UseForTests"
		static let simulatorUseQACloneButton = "QAW_SimulatorControl_UseQAClone"
		static let proofViewerThumbnailPrefix = "QAW_ProofViewer_Thumb_"
		static let proofViewerOpenExternally = "QAW_ProofViewer_OpenExternally"
		static let proofViewerShowInFinder = "QAW_ProofViewer_ShowInFinder"
		static let reset = "QAW_Reset"
		static let resetItemPrefix = "QAW_Reset_Item_"
		static let resetStartButton = "QAW_Reset_Start"
		static let resetConfirmButton = "QAW_Reset_Confirm"
		static let resetRefreshButton = "QAW_Reset_Refresh"
		static let resetLog = "QAW_Reset_Log"
		static let simulatorControl = "QAW_SimulatorControl"
		static let simulatorStatus = "QAW_SimulatorControl_Status"
		static let simulatorDevicePicker = "QAW_SimulatorControl_DevicePicker"
		static let simulatorBootButton = "QAW_SimulatorControl_Boot"
		static let simulatorShutdownButton = "QAW_SimulatorControl_Shutdown"
		static let simulatorShowButton = "QAW_SimulatorControl_Show"
		static let simulatorRefreshButton = "QAW_SimulatorControl_Refresh"
		static let simulatorBlendedToggle = "QAW_SimulatorControl_BlendedToggle"
		static let simulatorBundleField = "QAW_SimulatorControl_BundleField"
		static let simulatorRelaunchButton = "QAW_SimulatorControl_Relaunch"
		static let simulatorKillButton = "QAW_SimulatorControl_Kill"
		static let simulatorLinkField = "QAW_SimulatorControl_LinkField"
		static let simulatorOpenLinkButton = "QAW_SimulatorControl_OpenLink"
		static let deeplinks = "QAW_Deeplinks"
		static let deeplinkRouteSearchField = "QAW_Deeplinks_RouteSearch"
		static let deeplinkRoutePicker = "QAW_Deeplinks_RoutePicker"
		static let deeplinkParamFieldPrefix = "QAW_Deeplinks_Param_"
		static let deeplinkParamFields = "QAW_Deeplinks_ParamFields"
		static let deeplinkLinkRow = "QAW_Deeplinks_LinkRow"
		static let deeplinkSaveButton = "QAW_Deeplinks_Save"
		static let deeplinkEntryList = "QAW_Deeplinks_EntryList"
		static let deeplinkEntryRowPrefix = "QAW_Deeplinks_Entry_"
		static let deeplinkEntryOpenSuffix = "_Open"
		static let deeplinkEntryRemoveSuffix = "_Remove"
		static let simulatorDefaultKeyField = "QAW_SimulatorControl_DefaultKey"
		static let simulatorDefaultTypePicker = "QAW_SimulatorControl_DefaultType"
		static let simulatorDefaultValueField = "QAW_SimulatorControl_DefaultValue"
		static let simulatorDefaultReadButton = "QAW_SimulatorControl_DefaultRead"
		static let simulatorDefaultWriteButton = "QAW_SimulatorControl_DefaultWrite"
		static let simulatorDefaultDeleteButton = "QAW_SimulatorControl_DefaultDelete"
		static let simulatorResetPrivacyButton = "QAW_SimulatorControl_ResetPrivacy"
		static let simulatorResetKeychainButton = "QAW_SimulatorControl_ResetKeychain"
		static let simulatorEraseButton = "QAW_SimulatorControl_Erase"
		static let simulatorEraseConfirmButton = "QAW_SimulatorControl_EraseConfirm"
		static let simulatorStateBadge = "QAW_SimulatorControl_StateBadge"
		static let simulatorCopyUDIDButton = "QAW_SimulatorControl_CopyUDID"
		static let simulatorCardPrefix = "QAW_SimulatorControl_Card_"
		static let simulatorCardHeaderSuffix = "_Header"
		static let demoNextButton = "QAW_Demo_NextButton"
		static let demoStopButton = "QAW_Demo_StopButton"
		static let tutorialMenuItemPrefix = "QAW_Tutorial_MenuItem_"
		static let tutorialAutoShowToggle = "QAW_Tutorial_AutoShowToggle"
		static let tutorialResetButton = "QAW_Tutorial_ResetButton"
		static let tutorialReplayPrefix = "QAW_Tutorial_Replay_"
		static let settingsTutorials = "QAW_Settings_Tutorials"
		static let measureLayerBorderColor = "QAW_Measure_LayerBorderColor"
		static let measureLayerPass = "QAW_Measure_LayerPass"
		static let advanced = "QAW_Advanced"
		static let advancedPanelPicker = "QAW_Advanced_PanelPicker"
		static let fakeData = "QAW_Advanced_FakeData"
		static let fakeDataStatus = "QAW_Advanced_FakeData_Status"
		static let fakeDataMasterSwitch = "QAW_Advanced_FakeData_MasterSwitch"
		static let fakeDataNetworkLensButton = "QAW_Advanced_FakeData_NetworkLensButton"
		static let fakeDataRuleList = "QAW_Advanced_FakeData_RuleList"
		static let fakeDataRulePrefix = "QAW_Advanced_FakeData_Rule_"
		static let fakeDataRuleTogglePrefix = "QAW_Advanced_FakeData_RuleToggle_"
		static let fakeDataVariantPickerPrefix = "QAW_Advanced_FakeData_VariantPicker_"
		static let fakeDataVariantDetail = "QAW_Advanced_FakeData_VariantDetail"
		static let fakeDataCallList = "QAW_Advanced_FakeData_CallList"
		static let fakeDataCallPrefix = "QAW_Advanced_FakeData_Call_"
		static let fakeDataCallBody = "QAW_Advanced_FakeData_CallBody"
		static let recordedSteps = "QAW_Advanced_RecordedSteps"
		static let recordedStepsSearch = "QAW_Advanced_RecordedSteps_Search"
		static let recordedStepsReloadButton = "QAW_Advanced_RecordedSteps_ReloadButton"
		static let recordedStepsLint = "QAW_Advanced_RecordedSteps_Lint"
		static let recordedStepsList = "QAW_Advanced_RecordedSteps_List"
		static let recordedStepsRowPrefix = "QAW_Advanced_RecordedSteps_Row_"
		static let recordedStepsDetail = "QAW_Advanced_RecordedSteps_Detail"
		static let recordedStepsReplayButton = "QAW_Advanced_RecordedSteps_ReplayButton"
		static let phoneRemote = "QAW_Advanced_PhoneRemote"
		static let phoneRemoteHost = "QAW_Advanced_PhoneRemote_Host"
		static let phoneRemoteKindPicker = "QAW_Advanced_PhoneRemote_KindPicker"
		static let phoneRemoteFieldPrefix = "QAW_Advanced_PhoneRemote_Field_"
		static let phoneRemoteSendButton = "QAW_Advanced_PhoneRemote_SendButton"
		static let phoneRemoteResult = "QAW_Advanced_PhoneRemote_Result"
		static let phoneRemoteHistory = "QAW_Advanced_PhoneRemote_History"
		static let phoneRemoteHistoryRowPrefix = "QAW_Advanced_PhoneRemote_History_"
	}
}
