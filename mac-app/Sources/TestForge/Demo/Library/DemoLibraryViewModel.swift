import AVFoundation
import Foundation

enum DemoLibraryState: Equatable {
	case loading
	case empty
	case loaded([DemoRecording])
	case failed(message: String)
}

/// Reports › Demos (D-177): recorded demo videos, played in AVKit's own player in the chosen language.
/// Selecting a row opens it paused (D-179); the person presses play.
@MainActor
final class DemoLibraryViewModel: ObservableObject {
	@Published private(set) var state: DemoLibraryState = .loading
	@Published private(set) var player: AVPlayer?
	@Published private(set) var isPlaying = false
	@Published private(set) var isRefreshing = false
	@Published var selectedId: String? {
		didSet {
			if oldValue != selectedId {
				openSelected()
			}
		}
	}
	@Published var language: DemoLanguage = .english {
		didSet {
			if oldValue != language {
				switchLanguage()
			}
		}
	}

	private let service: DemoLibraryListing
	private let desktop: DesktopActing
	private var recordings: [DemoRecording] = []
	private var playbackObservation: NSKeyValueObservation?

	init(service: DemoLibraryListing, desktop: DesktopActing) {
		self.service = service
		self.desktop = desktop
	}

	var selectedRecording: DemoRecording? {
		recordings.first { $0.id == selectedId }
	}

	/// The language actually shown; a demo rendered in one language only plays that one.
	var playingLanguage: DemoLanguage? {
		guard let recording = selectedRecording else {
			return nil
		}
		return recording.videos[language] == nil ? recording.languages.first : language
	}

	func load() {
		guard !isRefreshing else {
			return
		}
		isRefreshing = true
		let service = service
		Task { [weak self] in
			do {
				let recordings = try await service.recordings()
				self?.recordings = recordings
				self?.state = recordings.isEmpty ? .empty : .loaded(recordings)
			} catch {
				self?.state = .failed(message: error.localizedDescription)
			}
			self?.isRefreshing = false
		}
	}

	func play() {
		player?.play()
	}

	func pause() {
		player?.pause()
	}

	func revealPlaying() {
		guard let recording = selectedRecording,
			let url = videoURL(for: recording)
		else {
			return
		}
		desktop.reveal(url: url)
	}

	private func openSelected() {
		player?.pause()
		playbackObservation = nil
		isPlaying = false
		guard let recording = selectedRecording,
			let url = videoURL(for: recording)
		else {
			player = nil
			return
		}
		let player = AVPlayer(url: url)
		playbackObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
			let isPlaying = player.timeControlStatus != .paused
			Task { @MainActor [weak self] in
				self?.isPlaying = isPlaying
			}
		}
		self.player = player
	}

	/// Keeps the position and play state, so a reader can switch language mid-demo.
	private func switchLanguage() {
		guard let player,
			let recording = selectedRecording,
			let url = videoURL(for: recording)
		else {
			return
		}
		let position = player.currentTime()
		let wasPlaying = player.rate > 0
		player.replaceCurrentItem(with: AVPlayerItem(url: url))
		player.seek(to: position, toleranceBefore: .zero, toleranceAfter: .zero)
		if wasPlaying {
			player.play()
		}
		objectWillChange.send()
	}

	private func videoURL(for recording: DemoRecording) -> URL? {
		recording.videos[language] ?? recording.languages.first.flatMap { recording.videos[$0] }
	}
}
