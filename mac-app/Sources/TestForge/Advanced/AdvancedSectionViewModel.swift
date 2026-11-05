import Foundation
import SwiftUI

enum AdvancedPanel: String, CaseIterable, Identifiable {
	case fakeData
	case recordedSteps
	case phoneRemote

	var id: String {
		rawValue
	}

	var title: LocalizedStringKey {
		switch self {
			case .fakeData:
				return "Network Mocks"
			case .recordedSteps:
				return "Recorded steps"
			case .phoneRemote:
				return "Simulator Driver"
		}
	}
}

struct AdvancedServices {
	let store: StateStore
	let mockService: MockActing
	let macroService: MacroActing
	let driverService: DriverCommanding
}

/// Advanced section: builds the three panel view models and only switches between them.
@MainActor
final class AdvancedSectionViewModel: ObservableObject {
	@Published var selectedPanel: AdvancedPanel = .fakeData

	let fakeDataViewModel: FakeDataViewModel
	let recordedStepsViewModel: RecordedStepsViewModel
	let phoneRemoteViewModel: PhoneRemoteViewModel

	init(services: AdvancedServices) {
		fakeDataViewModel = FakeDataViewModel(store: services.store, service: services.mockService)
		recordedStepsViewModel = RecordedStepsViewModel(service: services.macroService)
		phoneRemoteViewModel = PhoneRemoteViewModel(service: services.driverService)
	}
}
