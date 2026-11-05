import CoreGraphics
import Foundation

/// D-195: the shared loading style and Tests › What this case feeds the app.
extension TestForgeConstants.Accessibility {
	static let loadingState = "QAW_LoadingState"
	static let testsInputsPanel = "QAW_Tests_InputsPanel"
	static let testsInputsDeeplinkPrefix = "QAW_Tests_InputsDeeplink_"
	static let testsInputsMockPrefix = "QAW_Tests_InputsMock_"
	static let testsInputsCopyPrefix = "QAW_Tests_InputsCopy_"
	static let testsInputsDownloadPrefix = "QAW_Tests_InputsDownload_"
	static let testsInputsDownloadAll = "QAW_Tests_InputsDownloadAll"
}

extension TestForgeConstants.Tests {
	static let inputsBodyMaxHeight: CGFloat = 240
}

extension TestForgeConstants {
	enum Loading {
		/// Below this, the elapsed time is noise; past it, it tells a person the work hasn't stalled.
		static let showElapsedAfter: TimeInterval = 4
		static let tick: TimeInterval = 1
	}
}

/// D-196: Tests › Verify my changes.
extension TestForgeConstants.Accessibility {
	static let testsVerifyButton = "QAW_Tests_VerifyButton"
	static let verifySheet = "QAW_Verify_Sheet"
	static let verifyBase = "QAW_Verify_Base"
	static let verifyIncludeLocal = "QAW_Verify_IncludeLocal"
	static let verifyList = "QAW_Verify_List"
	static let verifyCaseRowPrefix = "QAW_Verify_Case_"
	static let verifyUncovered = "QAW_Verify_Uncovered"
	static let verifyCheck = "QAW_Verify_Check"
	static let verifyReplay = "QAW_Verify_Replay"
	static let verifyCancel = "QAW_Verify_Cancel"
}

extension TestForgeConstants.Tests {
	static let verifyListHeight: CGFloat = 220
}

/// D-197: Simulator › Real devices.
extension TestForgeConstants.Accessibility {
	static let physicalDevices = "QAW_PhysicalDevices"
	static let physicalDevicesRefresh = "QAW_PhysicalDevices_Refresh"
	static let physicalDevicePicker = "QAW_PhysicalDevices_Picker"
	static let physicalDeviceRowPrefix = "QAW_PhysicalDevices_Row_"
	static let physicalDeviceBlockers = "QAW_PhysicalDevices_Blockers"
	static let physicalDeviceUseButton = "QAW_PhysicalDevices_Use"
}
