import Foundation

@MainActor
protocol OnboardingPresenting: ObservableObject {
	var isPresented: Bool { get set }
	var step: OnboardingStep { get }
	var role: OnboardingRole { get set }
	var content: OnboardingPageContent { get }
	var canGoBack: Bool { get }
	var isLastStep: Bool { get }

	func show(_ step: OnboardingStep)
	func goForward()
	func goBack()
	func close()
	func perform(_ action: OnboardingStartAction)
}

private enum OnboardingDefaultsKey {
	static let hasSeen = "onboarding.hasSeen"
	static let role = "onboarding.role"
}

/// The welcome tour (D-134): opens once on the first TestForge launch, again from Help or the ? menu.
/// Whole-class `@MainActor` is deliberate: it only switches pages and remembers two defaults.
@MainActor
final class OnboardingViewModel: OnboardingPresenting {
	@Published var isPresented = false {
		didSet {
			if oldValue,
				!isPresented {
				didClose()
			}
		}
	}

	@Published private(set) var step: OnboardingStep = .welcome
	@Published var role: OnboardingRole {
		didSet {
			defaults.set(role.rawValue, forKey: OnboardingDefaultsKey.role)
		}
	}

	/// Set by the TestForge after it is built, like the demo's navigator.
	var actions: OnboardingActions?

	private let defaults: UserDefaults

	var content: OnboardingPageContent {
		OnboardingCatalog.page(step, role: role)
	}

	var canGoBack: Bool {
		step != .welcome
	}

	var isLastStep: Bool {
		step == OnboardingStep.allCases.last
	}

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
		let storedRole = defaults.string(forKey: OnboardingDefaultsKey.role).flatMap(OnboardingRole.init(rawValue:))
		role = storedRole ?? .qa
	}

	/// Opens the tour only the first time; returns whether it did, so screen tips can wait for it.
	@discardableResult
	func presentIfFirstTime() -> Bool {
		guard !defaults.bool(forKey: OnboardingDefaultsKey.hasSeen) else {
			return false
		}
		present()
		return true
	}

	func present() {
		step = .welcome
		isPresented = true
	}

	func show(_ step: OnboardingStep) {
		self.step = step
	}

	func goForward() {
		guard let next = OnboardingStep(rawValue: step.rawValue + 1) else {
			close()
			return
		}
		step = next
	}

	func goBack() {
		guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else {
			return
		}
		step = previous
	}

	func close() {
		isPresented = false
	}

	func perform(_ action: OnboardingStartAction) {
		close()
		actions?.perform(action)
	}

	private func didClose() {
		defaults.set(true, forKey: OnboardingDefaultsKey.hasSeen)
		actions?.didClose()
	}
}
