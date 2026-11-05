import Foundation
import UniformTypeIdentifiers

enum SessionExportPhase: Equatable {
	case loading
	case ready(SessionExportPreview)
	case exporting
	case finished(SessionExportOutcome)
	case failed(message: String)
}

/// Tests › Export session…: shows what the zip will hold, asks where to save it, then reports the result.
final class SessionExportViewModel: ObservableObject {
	@MainActor @Published var isPresented = false
	@MainActor @Published private(set) var phase: SessionExportPhase = .loading
	@MainActor @Published var isMediaIncluded = false

	private let service: SessionExporting
	private let desktop: DesktopActing
	private var preview: SessionExportPreview?

	init(service: SessionExporting, desktop: DesktopActing) {
		self.service = service
		self.desktop = desktop
	}

	@MainActor
	func begin() {
		phase = .loading
		isPresented = true
		Task { [weak self] in
			await self?.loadPreview()
		}
	}

	@MainActor
	func export() {
		guard let preview else {
			return
		}
		let isMediaIncluded = isMediaIncluded
		Task { [weak self] in
			guard let self else {
				return
			}
			let zipType = UTType.zip
			guard let fileURL = await desktop.chooseSaveLocation(suggestedFileName: preview.fileName, contentType: zipType) else {
				return
			}
			phase = .exporting
			do {
				phase = .finished(try await service.export(to: fileURL, includeMedia: isMediaIncluded))
			} catch {
				phase = .failed(message: error.localizedDescription)
			}
		}
	}

	@MainActor
	func revealExport() {
		guard case .finished(let outcome) = phase else {
			return
		}
		desktop.reveal(url: URL(fileURLWithPath: outcome.path))
	}

	@MainActor
	func dismiss() {
		isPresented = false
	}

	@MainActor
	var mediaToggleTitle: String {
		guard let preview, preview.mediaFiles > 0 else {
			return String(localized: "Include screenshots and videos (none found)")
		}
		let size = ByteCountFormatter.string(fromByteCount: preview.mediaBytes, countStyle: .file)
		return String(localized: "Include screenshots and videos (\(preview.mediaFiles) files, \(size))")
	}

	@MainActor
	var canIncludeMedia: Bool {
		(preview?.mediaFiles ?? 0) > 0
	}

	static func summaryLines(for preview: SessionExportPreview) -> [String] {
		let summary = preview.summary
		return [
			String(localized: "\(summary.cases) cases with their steps, expected results and local edits"),
			String(localized: "\(summary.recorded) recordings · \(summary.passed) passed · \(summary.failed) failed · \(summary.undecided) undecided · \(summary.notRun) not run"),
			String(localized: "Each case's last verdict, every run of it, and reviews from \(preview.runs) batch runs"),
		]
	}

	static func outcomeText(for outcome: SessionExportOutcome) -> String {
		let size = ByteCountFormatter.string(fromByteCount: outcome.bytes, countStyle: .file)
		let saved = String(localized: "Saved \(outcome.cases) cases and \(outcome.mediaFiles) media files (\(size)).")
		guard !outcome.missingMedia.isEmpty else {
			return saved
		}
		return saved + " " + String(localized: "\(outcome.missingMedia.count) media files were no longer on disk and were skipped.")
	}

	private func loadPreview() async {
		do {
			let loaded = try await service.preview()
			preview = loaded
			await MainActor.run {
				phase = .ready(loaded)
			}
		} catch {
			await MainActor.run {
				phase = .failed(message: error.localizedDescription)
			}
		}
	}
}
