import SwiftUI

/// Sizes are fractions of the Simulator screen's width, so the overlay reads the same at any window size.
enum ExplainOverlayConstants {
	enum Caption {
		static let fontShare: CGFloat = 0.046
		static let maxWidthShare: CGFloat = 0.9
		static let horizontalPadFontShare: CGFloat = 0.55
		static let verticalPadFontShare: CGFloat = 0.4
		static let cornerFontShare: CGFloat = 0.6
		static let measureSlackFontShare: CGFloat = 0.3
		static let marginShare: CGFloat = 0.04
		static let topInsetShare: CGFloat = 0.12
		static let bottomInsetShare: CGFloat = 0.07
		static let gapShare: CGFloat = 0.1
		static let minSideWidthShare: CGFloat = 0.38
		static let tailLengthShare: CGFloat = 0.03
		static let tailHalfWidthShare: CGFloat = 0.022
		static let borderShare: CGFloat = 0.004
		static let moveSeconds: Double = 0.25
		static let background = Color.black.opacity(0.8)
		static let plainBorder = Color.white.opacity(0.3)
	}

	enum Card {
		static let titleShare: CGFloat = 0.066
		static let headingShare: CGFloat = 0.032
		static let bodyShare: CGFloat = 0.044
		static let marginShare: CGFloat = 0.08
		static let topShare: CGFloat = 0.16
		static let background = Color(nsColor: DemoLayout.cardBackground)
		static let accent = Color(nsColor: DemoLayout.accent)
	}

	/// Centered result: a big check or cross, the colored verdict, then the case.
	enum Result {
		static let symbolShare: CGFloat = 0.22
		static let titleShare: CGFloat = 0.074
		static let spacingShare: CGFloat = 0.035
		static let textWidthShare: CGFloat = 0.84
		static let secondary = Color.white.opacity(0.65)
	}

	enum Pointer {
		static let insetShare: CGFloat = 0.012
		static let cornerShare: CGFloat = 0.02
		static let lineShare: CGFloat = 0.0045
		static let tapDotShare: CGFloat = 0.03
		static let badgeShare: CGFloat = 0.036
		static let badgeHeightFontShare: CGFloat = 1.9
		static let badgePadFontShare: CGFloat = 0.55
		static let badgeGapShare: CGFloat = 0.02
		static let badgeMarginShare: CGFloat = 0.03
		static let fillOpacity: Double = 0.14
		static let dotOpacity: Double = 0.75
	}

	enum Busy {
		static let fontShare: CGFloat = 0.036
		static let maxWidthShare: CGFloat = 0.9
		static let topShare: CGFloat = 0.14
		static let background = Color.black.opacity(0.82)
		static let border = Color.white.opacity(0.25)
	}

	enum Connector {
		static let lineShare: CGFloat = 0.006
		static let dotShare: CGFloat = 0.022
	}

	enum Accessibility {
		static let overlay = "QAW_ExplainOverlay"
		static let content = "QAW_StepOverlay_Content"
		static let card = "QAW_ExplainOverlay_Card"
		static let cardTitle = "QAW_ExplainOverlay_CardTitle"
		static let cardHeading = "QAW_ExplainOverlay_CardHeading"
		static let cardBody = "QAW_ExplainOverlay_CardBody"
		static let result = "QAW_ExplainOverlay_Result"
		static let resultSymbol = "QAW_ExplainOverlay_ResultSymbol"
		static let resultTitle = "QAW_ExplainOverlay_ResultTitle"
		static let resultHeading = "QAW_ExplainOverlay_ResultHeading"
		static let resultBody = "QAW_ExplainOverlay_ResultBody"
		static let caption = "QAW_ExplainOverlay_Caption"
		static let captionText = "QAW_ExplainOverlay_CaptionText"
		static let captionBubble = "QAW_ExplainOverlay_CaptionBubble"
		static let pointer = "QAW_ExplainOverlay_Pointer"
		static let pointerOutline = "QAW_ExplainOverlay_PointerOutline"
		static let pointerTapDot = "QAW_ExplainOverlay_PointerTapDot"
		static let pointerBadge = "QAW_ExplainOverlay_PointerBadge"
		static let busyOverlay = "QAW_StepOverlay_Busy"
		static let busyBanner = "QAW_StepOverlay_BusyBanner"
		static let busySpinner = "QAW_StepOverlay_BusySpinner"
		static let busyText = "QAW_StepOverlay_BusyText"
		static let connector = "QAW_ExplainOverlay_Connector"
		static let connectorLine = "QAW_ExplainOverlay_ConnectorLine"
		static let connectorDot = "QAW_ExplainOverlay_ConnectorDot"
		static let preview = "QAW_ExplainPreview"
		static let previewFrame = "QAW_ExplainPreview_Frame"
	}
}
