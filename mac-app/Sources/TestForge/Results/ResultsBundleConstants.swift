import CoreGraphics

/// D-162 run bundles; kept apart so the main constants enum stays under the type-length limit.
extension TestForgeConstants.Results {
	static let bundleSheetWidth: CGFloat = 560
	static let bundleMockListMaxHeight: CGFloat = 220
}

extension TestForgeConstants.Accessibility {
	static let resultsExportBundleButton = "QAW_Results_ExportBundleButton"
	static let resultsImportBundleButton = "QAW_Results_ImportBundleButton"
	static let resultsBundleSheet = "QAW_Results_BundleSheet"
	static let resultsBundleImportButton = "QAW_Results_BundleImportButton"
	static let resultsBundleReplayButton = "QAW_Results_BundleReplayButton"
	static let resultsBundleMockList = "QAW_Results_BundleMockList"
	static let resultsBundleArmPrefix = "QAW_Results_BundleArm_"
}
