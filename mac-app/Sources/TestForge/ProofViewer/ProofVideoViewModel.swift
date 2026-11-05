import AVFoundation
import Combine

enum ProofVideoState: Equatable {
	case empty
	case loading
	case ready
	case failed(message: String)
}

/// One proof video: play, pause, stop, frame steps, speed, seeking and zoom (the player view's magnification).
@MainActor
final class ProofVideoViewModel: ObservableObject {
	@Published private(set) var state: ProofVideoState = .empty
	@Published private(set) var isPlaying = false
	@Published private(set) var currentSeconds: Double = 0
	@Published private(set) var durationSeconds: Double = 0
	@Published private(set) var rate: Float = 1
	@Published private(set) var magnification: CGFloat = 1

	let player = AVPlayer()

	private var timeObserver: Any?
	private var loadTask: Task<Void, Never>?
	private var cancellables = Set<AnyCancellable>()

	init() {
		observePlayback()
	}

	deinit {
		loadTask?.cancel()
		if let timeObserver {
			player.removeTimeObserver(timeObserver)
		}
	}

	var currentTimeText: String {
		Self.timeText(seconds: currentSeconds)
	}

	var durationText: String {
		Self.timeText(seconds: durationSeconds)
	}

	static func rateText(rate: Float) -> String {
		rate.formatted(.number.precision(.fractionLength(0...2))) + "×"
	}

	/// Tenths of a second, because proof timing questions ("did it appear within 2 s?") need more than whole seconds.
	private static func timeText(seconds: Double) -> String {
		let tenths = Int((max(seconds, 0) * 10).rounded(.down))
		let minutes = tenths / 600
		let remainingSeconds = (tenths % 600) / 10
		return String(format: "%d:%02d.%d", minutes, remainingSeconds, tenths % 10)
	}

	func load(url: URL) {
		loadTask?.cancel()
		player.pause()
		state = .loading
		currentSeconds = 0
		durationSeconds = 0
		magnification = 1
		let item = AVPlayerItem(url: url)
		player.replaceCurrentItem(with: item)
		loadTask = Task { [weak self] in
			do {
				let duration = try await item.asset.load(.duration)
				guard !Task.isCancelled else {
					return
				}
				self?.durationSeconds = duration.seconds.isFinite ? duration.seconds : 0
				self?.state = .ready
			} catch {
				self?.state = .failed(message: String(localized: "\(url.lastPathComponent) can't be played: \(error.localizedDescription)"))
			}
		}
	}

	func unload() {
		loadTask?.cancel()
		player.pause()
		player.replaceCurrentItem(with: nil)
		state = .empty
	}

	func togglePlay() {
		if isPlaying {
			player.pause()
		} else {
			if durationSeconds > 0, currentSeconds >= durationSeconds - TestForgeConstants.ProofViewer.endTolerance {
				player.seek(to: .zero)
			}
			player.playImmediately(atRate: rate)
		}
	}

	func stop() {
		player.pause()
		seek(toSeconds: 0)
	}

	/// Pauses first: a frame step only makes sense on a still picture.
	func step(byFrames frameCount: Int) {
		player.pause()
		player.currentItem?.step(byCount: frameCount)
	}

	func seek(toSeconds seconds: Double) {
		let time = CMTime(seconds: seconds, preferredTimescale: TestForgeConstants.ProofViewer.seekTimescale)
		player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
		currentSeconds = seconds
	}

	func setRate(to newRate: Float) {
		rate = newRate
		if isPlaying {
			player.rate = newRate
		}
	}

	func zoomIn() {
		magnification = min(magnification * TestForgeConstants.ProofViewer.zoomStep, TestForgeConstants.ProofViewer.maximumZoom)
	}

	func zoomOut() {
		magnification = max(magnification / TestForgeConstants.ProofViewer.zoomStep, 1)
	}

	func resetZoom() {
		magnification = 1
	}

	private func observePlayback() {
		let interval = CMTime(
			seconds: TestForgeConstants.ProofViewer.timeUpdateSeconds,
			preferredTimescale: TestForgeConstants.ProofViewer.seekTimescale
		)
		timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
			MainActor.assumeIsolated {
				self?.currentSeconds = time.seconds.isFinite ? time.seconds : 0
			}
		}
		player.publisher(for: \.timeControlStatus)
			.receive(on: DispatchQueue.main)
			.sink { [weak self] status in
				self?.isPlaying = status != .paused
			}
			.store(in: &cancellables)
	}
}
