import AppKit
import Combine
import Foundation

struct StepOverlayDependencies {
	let store: StateStore
	let locator: SimulatorLocating
	let deviceScreenService: DeviceScreenReading
	let presenter: StepOverlayPresenting
	let preferences: TestForgePreferences
}

struct StepOutlineInputs {
	let narration: NarrationState?
	let geometry: SimulatorGeometry
	let fallbackScreen: DeviceScreen?
	let primaryScreenHeight: CGFloat
}

enum StepOutlineMapper {
	/// The working step of the running replay, placed on the Simulator; nil hides the outline rather than guessing.
	static func outline(inputs: StepOutlineInputs) -> StepOutline? {
		let geometry = inputs.geometry
		guard let run = inputs.narration?.runs.first(where: { $0.isRunning }),
			let step = run.steps.last(where: { $0.status == "working" }),
			let deviceFrame = step.frame,
			let devicePoints = run.screen?.size ?? inputs.fallbackScreen?.size
		else {
			return nil
		}
		let mapping = ScreenMapping(screenFrame: geometry.screenFrame, devicePoints: devicePoints)
		guard mapping.isCalibrated else {
			return nil
		}
		let elementRect = mapping.macRect(forDeviceRect: deviceFrame)
		let outlineRect = elementRect.offsetBy(dx: -geometry.screenFrame.minX, dy: -geometry.screenFrame.minY)
		let panelFrame = ScreenCoordinates.appKitRect(fromAccessibilityRect: geometry.screenFrame, primaryScreenHeight: inputs.primaryScreenHeight)
		return StepOutline(number: step.id, text: step.text, panelFrame: panelFrame, outlineRect: outlineRect)
	}
}

/// Recommendation #7: outlines on the Simulator the element the running replay acts on.
/// D-165: an explained replay's cards, subtitles and pointers show here too, whether or not outlines are on.
@MainActor
final class StepOverlayViewModel: ObservableObject {
	@Published private(set) var notice: String?

	private let dependencies: StepOverlayDependencies
	private var cancellables = Set<AnyCancellable>()
	private var trackingTask: Task<Void, Never>?
	private var leaseTask: Task<Void, Never>?
	private var cachedScreen: DeviceScreen?
	private var isTracking = false

	init(dependencies: StepOverlayDependencies) {
		self.dependencies = dependencies
		observePreference()
		observeExplainedRuns()
	}

	deinit {
		trackingTask?.cancel()
		leaseTask?.cancel()
	}

	private var isOutlineOn: Bool {
		dependencies.preferences.isStepOverlayOn
	}

	private func observePreference() {
		dependencies.preferences.$isStepOverlayOn
			.removeDuplicates()
			.sink { [weak self] isOn in
				self?.setLease(isOn: isOn)
				self?.startTrackingIfNeeded(isOutlineOn: isOn)
			}
			.store(in: &cancellables)
	}

	private func observeExplainedRuns() {
		dependencies.store.$slices
			.sink { [weak self] _ in
				guard let self else {
					return
				}
				startTrackingIfNeeded(isOutlineOn: isOutlineOn)
			}
			.store(in: &cancellables)
	}

	/// The server reads step frames only while the lease is renewed; an explained replay reads its own.
	private func setLease(isOn: Bool) {
		leaseTask?.cancel()
		let service = dependencies.deviceScreenService
		guard isOn else {
			leaseTask = Task {
				try? await service.leaseStepFrames(isOn: false)
			}
			return
		}
		leaseTask = Task {
			while !Task.isCancelled {
				try? await service.leaseStepFrames(isOn: true)
				try? await Task.sleep(for: TestForgeConstants.Overlay.leaseRenewal)
			}
		}
	}

	private func hasExplainedRun() -> Bool {
		let narration = dependencies.store.value(of: .narration, as: NarrationState.self)
		return ExplainOverlayMapper.activeRun(narration: narration, now: Date()) != nil
	}

	/// A running replay may put up a busy banner at any step, so the panel tracks it whatever the outline preference.
	private static func hasRunningReplay(_ narration: NarrationState?) -> Bool {
		narration?.runs.contains { $0.isRunning } ?? false
	}

	private func startTrackingIfNeeded(isOutlineOn: Bool) {
		let narration = dependencies.store.value(of: .narration, as: NarrationState.self)
		// A plain replay's banner never asks for Accessibility access; outlines and explained replays do.
		let isBannerOnly = Self.hasRunningReplay(narration) && dependencies.locator.isTrusted
		guard isOutlineOn || hasExplainedRun() || isBannerOnly else {
			if !isTracking {
				notice = nil
				dependencies.presenter.hide()
			}
			return
		}
		guard !isTracking else {
			return
		}
		if !dependencies.locator.isTrusted {
			dependencies.locator.requestTrust()
			notice = SimulatorBridgeError.notTrusted.localizedDescription
		}
		isTracking = true
		trackingTask = Task { [weak self] in
			while !Task.isCancelled {
				let shouldContinue = await self?.refresh() ?? false
				guard shouldContinue else {
					break
				}
				try? await Task.sleep(for: TestForgeConstants.Overlay.trackingInterval)
			}
			self?.isTracking = false
		}
	}

	/// Returns whether to keep tracking: outlines are on, or an explained replay is running or showing its result.
	private func refresh() async -> Bool {
		let narration = dependencies.store.value(of: .narration, as: NarrationState.self)
		let isExplaining = ExplainOverlayMapper.activeRun(narration: narration, now: Date()) != nil
		guard isOutlineOn || isExplaining || (Self.hasRunningReplay(narration) && dependencies.locator.isTrusted) else {
			notice = nil
			dependencies.presenter.hide()
			return false
		}
		let runningRun = narration?.runs.first { $0.isRunning }
		let hasFrame = runningRun?.steps.last { $0.status == "working" }?.frame != nil
		let isBusy = runningRun?.busy != nil
		guard isExplaining || hasFrame || isBusy else {
			dependencies.presenter.hide()
			return true
		}
		if cachedScreen == nil {
			cachedScreen = try? await dependencies.deviceScreenService.screen()
		}
		let locator = dependencies.locator
		let geometryResult = await Task.detached {
			Result { try locator.geometry() }
		}.value
		switch geometryResult {
			case .success(let geometry):
				notice = nil
				show(narration: narration, geometry: geometry, isExplaining: isExplaining)
			case .failure(let error):
				notice = error.localizedDescription
				dependencies.presenter.hide()
		}
		return true
	}

	private func show(narration: NarrationState?, geometry: SimulatorGeometry, isExplaining: Bool) {
		let content = content(narration: narration, geometry: geometry, isExplaining: isExplaining)
		guard let content,
			let windowNumber = geometry.windowNumber,
			geometry.isWindowOnScreen
		else {
			dependencies.presenter.hide()
			return
		}
		dependencies.presenter.show(content: content, aboveWindowNumber: windowNumber)
	}

	private func content(narration: NarrationState?, geometry: SimulatorGeometry, isExplaining: Bool) -> StepOverlayContent? {
		let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
		if isExplaining {
			let inputs = ExplainOverlayInputs(
				narration: narration,
				geometry: geometry,
				fallbackScreen: cachedScreen,
				primaryScreenHeight: primaryHeight,
				language: dependencies.preferences.explainLanguage,
				now: Date()
			)
			return ExplainOverlayMapper.overlay(inputs: inputs).map { StepOverlayContent.explain($0) }
		}
		let inputs = StepOutlineInputs(narration: narration, geometry: geometry, fallbackScreen: cachedScreen, primaryScreenHeight: primaryHeight)
		if isOutlineOn,
			let outline = StepOutlineMapper.outline(inputs: inputs) {
			return .outline(outline)
		}
		return StepBusyMapper.overlay(narration: narration, geometry: geometry, primaryScreenHeight: primaryHeight).map { StepOverlayContent.busy($0) }
	}
}
