import Combine
import Foundation

/// Simulator › Real devices (D-197): what's paired with this Mac, and for the one chosen, what stops tests on it.
/// Whole-class `@MainActor`: it maps one list to published state.
@MainActor
final class PhysicalDevicesViewModel: ObservableObject {
	@Published private(set) var state: PhysicalDevicesState = .loading
	@Published private(set) var devices: [PhysicalDevice] = []
	@Published var selectedId: String?

	private let service: TestDeviceActing
	private var task: Task<Void, Never>?

	init(service: TestDeviceActing) {
		self.service = service
	}

	deinit {
		task?.cancel()
	}

	var rows: [PhysicalDeviceRowModel] {
		devices.map { device in
			let details = [device.model, device.osVersion].compactMap { $0 }
			return PhysicalDeviceRowModel(
				id: device.id,
				name: device.name,
				detailText: details.joined(separator: " · "),
				stateText: stateText(for: device),
				isConnected: device.isConnected
			)
		}
	}

	var selectedDevice: PhysicalDevice? {
		devices.first { $0.id == selectedId }
	}

	func load(isFresh: Bool = false) {
		state = .loading
		let service = service
		task?.cancel()
		task = Task { [weak self] in
			do {
				let list = try await service.physicalDevices(isFresh: isFresh)
				self?.devices = list.devices
				self?.state = list.error.map { .failed(message: $0) } ?? .loaded
			} catch {
				self?.state = .failed(message: error.localizedDescription)
			}
		}
	}

	private func stateText(for device: PhysicalDevice) -> String {
		guard device.isConnected else {
			return String(localized: "Paired, not connected")
		}
		return device.connection == "cable" ? String(localized: "Connected by cable") : String(localized: "Connected over the network")
	}
}
