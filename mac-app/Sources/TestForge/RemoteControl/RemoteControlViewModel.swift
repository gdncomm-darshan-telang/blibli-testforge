import AppKit
import Combine
import Foundation

@MainActor
protocol RemoteControlPresenting: ObservableObject {
	var display: RemoteControlDisplay { get }
	var spawnMode: RemoteControlSpawnMode { get set }
	var qrImage: NSImage? { get }
	var isWorking: Bool { get }
	var errorMessage: String? { get }

	func start()
	func stop()
	func openSession()
	func copyLink()
}

/// The Remote Control panel (D-150): start / stop the supervised `claude remote-control`, and get the session to a phone.
/// Whole-class `@MainActor` is deliberate: it maps one slice and forwards two calls.
@MainActor
final class RemoteControlViewModel: RemoteControlPresenting {
	@Published private(set) var display = RemoteControlMapper.display(from: nil)
	@Published var spawnMode: RemoteControlSpawnMode = .sameDirectory
	@Published private(set) var qrImage: NSImage?
	@Published private(set) var isWorking = false
	@Published private(set) var errorMessage: String?

	private let store: StateStore
	private let service: RemoteControlActing
	private let desktop: DesktopActing
	private var cancellables = Set<AnyCancellable>()

	init(store: StateStore, service: RemoteControlActing, desktop: DesktopActing) {
		self.store = store
		self.service = service
		self.desktop = desktop
		store.$slices
			.receive(on: DispatchQueue.main)
			.sink { [weak self] _ in
				self?.refresh()
			}
			.store(in: &cancellables)
	}

	func start() {
		let spawnMode = spawnMode
		perform { service in
			try await service.start(spawnMode: spawnMode)
		}
	}

	func stop() {
		perform { service in
			try await service.stop()
		}
	}

	func openSession() {
		guard let url = display.openURL else {
			return
		}
		desktop.open(url: url)
	}

	func copyLink() {
		guard let url = display.openURL else {
			return
		}
		desktop.copy(text: url.absoluteString)
	}

	private func refresh() {
		let state = store.value(of: .remoteControl, as: RemoteControlState.self)
		let newDisplay = RemoteControlMapper.display(from: state)
		guard newDisplay != display else {
			return
		}
		if newDisplay.openURL != display.openURL {
			qrImage = newDisplay.openURL.flatMap(QRCodeRenderer.image(for:))
		}
		if let mode = state.flatMap({ RemoteControlSpawnMode(rawValue: $0.spawnMode) }),
			state?.isRunning == true {
			spawnMode = mode
		}
		display = newDisplay
	}

	private func perform(_ work: @escaping (RemoteControlActing) async throws -> Void) {
		guard !isWorking else {
			return
		}
		isWorking = true
		errorMessage = nil
		let service = service
		Task { [weak self] in
			do {
				try await work(service)
			} catch {
				self?.errorMessage = error.localizedDescription
			}
			self?.isWorking = false
		}
	}
}
