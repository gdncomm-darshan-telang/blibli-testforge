import Foundation

protocol AnnotatedImageSaving {
	func write(data: Data, to url: URL) throws

	/// `<name>-annotated.<ext>` beside the original, numbered when that name is taken.
	func copyURL(for original: URL) -> URL
}

struct AnnotatedImageStore: AnnotatedImageSaving {
	private let fileManager: FileManager

	init(fileManager: FileManager = .default) {
		self.fileManager = fileManager
	}

	func write(data: Data, to url: URL) throws {
		try data.write(to: url, options: .atomic)
	}

	func copyURL(for original: URL) -> URL {
		let folder = original.deletingLastPathComponent()
		let baseName = original.deletingPathExtension().lastPathComponent
		let fileExtension = original.pathExtension
		var candidate = folder.appendingPathComponent("\(baseName)-annotated").appendingPathExtension(fileExtension)
		var number = 2
		while fileManager.fileExists(atPath: candidate.path) {
			candidate = folder.appendingPathComponent("\(baseName)-annotated-\(number)").appendingPathExtension(fileExtension)
			number += 1
		}
		return candidate
	}
}
