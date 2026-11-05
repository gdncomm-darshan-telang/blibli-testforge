import AppKit
import Foundation

extension TestForgeViewModel: DemoNavigating {
	func showDemoStep(_ step: DemoStep) {
		switch step {
			case .getReady:
				startTutorial(.getReady)
			case .runningTests:
				startTutorial(.besideSimulator)
			case .results:
				startTutorial(.results)
			case .reports:
				startTutorial(.reports)
		}
	}
}

extension TestForgeViewModel {
	static func makeDemoViewModel(services: TestForgeServices) -> DemoRunViewModel {
		let dependencies = DemoRunDependencies(
			store: services.store,
			testCaseService: services.testCaseService,
			runControl: services.runControlService
		)
		return DemoRunViewModel(dependencies: dependencies)
	}
}
