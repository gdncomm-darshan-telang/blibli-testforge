import Foundation

enum OnboardingConstants {
	enum Layout {
		static let width: CGFloat = 880
		static let height: CGFloat = 600
		static let stepListWidth: CGFloat = 190
		static let cardMinWidth: CGFloat = 240
		static let cardSymbolWidth: CGFloat = 28
		static let cardCornerRadius: CGFloat = 10
		static let numberDiameter: CGFloat = 26
		static let roleCardHeight: CGFloat = 120
		static let selectedBorderWidth: CGFloat = 2
		static let borderWidth: CGFloat = 1
		static let borderOpacity = 0.3
		static let surfaceOpacity = 0.06
	}

	enum Accessibility {
		static let sheet = "QAW_Onboarding"
		static let stepPrefix = "QAW_Onboarding_Step_"
		static let rolePrefix = "QAW_Onboarding_Role_"
		static let rolePicker = "QAW_Onboarding_RolePicker"
		static let cardPrefix = "QAW_Onboarding_Card_"
		static let flowStepPrefix = "QAW_Onboarding_Flow_"
		static let claudeMarkerPrefix = "QAW_Onboarding_ClaudeMarker_"
		static let startActionPrefix = "QAW_Onboarding_Start_"
		static let backButton = "QAW_Onboarding_Back"
		static let nextButton = "QAW_Onboarding_Next"
		static let skipButton = "QAW_Onboarding_Skip"
		static let helpMenuItem = "QAW_Onboarding_HelpMenuItem"
	}
}
