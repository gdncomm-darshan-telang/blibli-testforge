import SwiftUI

/// The sheets Get Ready opens; each is owned by MainViewModel and handed down together.
struct GetReadyCompanions {
	let prerequisites: PrerequisitesViewModel
	let prepareCode: PrepareCodeViewModel
	let runQueue: RunQueueViewModel
	let git: GitControlViewModel
}

/// Observes each sheet's own view model so its `isShown` drives the sheet directly.
struct GetReadySheetsModifier: ViewModifier {
	@ObservedObject var prerequisites: PrerequisitesViewModel
	@ObservedObject var prepareCode: PrepareCodeViewModel
	@ObservedObject var runQueue: RunQueueViewModel
	@ObservedObject var git: GitControlViewModel

	func body(content: Content) -> some View {
		content
			.sheet(isPresented: $prerequisites.isShown) {
				PrerequisitesSheetView(viewModel: prerequisites)
			}
			.sheet(isPresented: $prepareCode.isShown) {
				PrepareCodeSheetView(viewModel: prepareCode)
			}
			.sheet(isPresented: $runQueue.isShown) {
				RunQueueSheetView(viewModel: runQueue)
			}
			.sheet(isPresented: $git.isShown) {
				GitControlSheetView(viewModel: git)
			}
	}
}

extension View {
	func getReadySheets(companions: GetReadyCompanions) -> some View {
		modifier(GetReadySheetsModifier(
			prerequisites: companions.prerequisites,
			prepareCode: companions.prepareCode,
			runQueue: companions.runQueue,
			git: companions.git
		))
	}
}
