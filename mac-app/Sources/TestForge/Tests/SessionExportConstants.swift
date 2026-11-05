import CoreGraphics
import Foundation

/// Tests › Export session… (D-173).
enum SessionExportConstants {
	static let sheetWidth: CGFloat = 520

	/// Copying every proof video into the zip can take minutes on a long session.
	static let timeout: TimeInterval = 900

	enum Accessibility {
		static let sheet = "QAW_SessionExport_Sheet"
		static let title = "QAW_SessionExport_Title"
		static let progress = "QAW_SessionExport_Progress"
		static let outcome = "QAW_SessionExport_Outcome"
		static let mediaToggle = "QAW_SessionExport_MediaToggle"
		static let reveal = "QAW_SessionExport_RevealButton"
		static let cancel = "QAW_SessionExport_CancelButton"
		static let button = "QAW_SessionExport_ExportButton"
		static let done = "QAW_SessionExport_DoneButton"
	}
}
