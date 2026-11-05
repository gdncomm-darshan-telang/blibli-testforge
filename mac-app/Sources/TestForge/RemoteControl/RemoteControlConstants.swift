import Foundation

enum RemoteControlConstants {
	enum Layout {
		static let panelWidth: CGFloat = 420
		static let qrSide: CGFloat = 132
	}

	enum Copy {
		static let footnote = String(
			localized: """
			Sessions run here in the repo with your plugins. Approvals and questions come to your phone; pushing, \
			building for testing and erasing a simulator always ask first.
			"""
		)
	}

	enum Accessibility {
		static let button = "QAW_RemoteControl_Button"
		static let panel = "QAW_RemoteControl_Panel"
		static let qrCode = "QAW_RemoteControl_QR"
		static let openButton = "QAW_RemoteControl_Open"
		static let copyButton = "QAW_RemoteControl_Copy"
		static let spawnModePicker = "QAW_RemoteControl_SpawnMode"
		static let startButton = "QAW_RemoteControl_Start"
		static let stopButton = "QAW_RemoteControl_Stop"
	}
}
