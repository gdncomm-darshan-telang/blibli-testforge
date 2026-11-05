import Foundation

enum ClaudeConstants {
	enum Transcript {
		static let resultPreviewLength = 200
		static let argumentLength = 140
		static let approvalDetailLength = 3000
		static let approvalDetailMaxHeight: CGFloat = 220
		static let detailMaxHeight: CGFloat = 260
		static let bubbleCornerRadius: CGFloat = 8
		static let userBubbleOpacity = 0.12
		static let bottomAnchorId = "claude-transcript-bottom"
	}

	enum Composer {
		static let minHeight: CGFloat = 56
		static let maxHeight: CGFloat = 140
		static let lineRange = 2...6
	}

	enum QuickReply {
		static let answers = [String(localized: "Yes"), String(localized: "No")]
		/// D-192: steering while a run is still going, so a stuck run is redirected without typing.
		static let runSteering = [
			String(localized: "Take a screenshot and tell me what you see"),
			String(localized: "Use the case's recording if it has one"),
			String(localized: "Stop and tell me what's blocking you"),
		]
		static let runFollowUps = [
			String(localized: "Investigate what went wrong and fix it"),
			String(localized: "Explain step by step what happened"),
			String(localized: "Try the last step again"),
		]
	}

	enum Sessions {
		static let listLimit = 15
	}

	enum Stream {
		static let reconnectDelayNanoseconds: UInt64 = 2_000_000_000
	}

	enum Accessibility {
		static let activityStrip = "QAW_Claude_ActivityStrip"
		static let activityText = "QAW_Claude_ActivityText"
		static let section = "QAW_Claude"
		static let transcript = "QAW_Claude_Transcript"
		static let composerField = "QAW_Claude_Composer"
		static let sendButton = "QAW_Claude_Send"
		static let stopButton = "QAW_Claude_Stop"
		static let newConversationButton = "QAW_Claude_NewConversation"
		static let sessionMenu = "QAW_Claude_SessionMenu"
		static let detailsToggle = "QAW_Claude_DetailsToggle"
		static let quickReplyPrefix = "QAW_Claude_QuickReply_"
		static let awaitingReplyBanner = "QAW_Claude_AwaitingReply"
		static let screenshotToggle = "QAW_Claude_AttachScreenshot"
		static let retryButton = "QAW_Claude_Retry"
		static let rowPrefix = "QAW_Claude_Row_"
		static let approveButton = "QAW_Claude_Approve"
		static let alwaysAllowButton = "QAW_Claude_AlwaysAllow"
		static let denyButton = "QAW_Claude_Deny"
		static let sendAnswerButton = "QAW_Claude_SendAnswer"
		static let skipQuestionButton = "QAW_Claude_SkipQuestion"
		static let otherAnswerField = "QAW_Claude_OtherAnswer"
	}
}
