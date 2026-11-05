import AppKit
import UniformTypeIdentifiers

protocol DesktopActing {
	func open(url: URL)
	func copy(text: String)
	func copy(pngData: Data)
	func reveal(url: URL)

	/// Asks where to save a PNG with a save panel; nil when the person cancels.
	@MainActor
	func saveImage(pngData: Data, suggestedFileName: String) async throws -> URL?

	/// Asks where to save with a save panel; nil when the person cancels.
	@MainActor
	func saveText(text: String, suggestedFileName: String) async throws -> URL?

	/// Asks where something else (the server) will write a file; nil when the person cancels.
	@MainActor
	func chooseSaveLocation(suggestedFileName: String, contentType: UTType) async -> URL?

	/// Asks where to save a file of `contentType` with a save panel; nil when the person cancels.
	@MainActor
	func saveData(_ data: Data, suggestedFileName: String, contentType: UTType) async throws -> URL?

	/// Asks for a folder with an open panel (new folders allowed); nil when the person cancels.
	@MainActor
	func chooseFolder(prompt: String, startingAt startingURL: URL?) async -> URL?

	/// Asks for one file of the given types with an open panel; nil when the person cancels.
	@MainActor
	func chooseFile(prompt: String, contentTypes: [UTType]) async -> URL?
}

struct SystemDesktop: DesktopActing {
	private let workspace: NSWorkspace
	private let pasteboard: NSPasteboard

	init(workspace: NSWorkspace = .shared, pasteboard: NSPasteboard = .general) {
		self.workspace = workspace
		self.pasteboard = pasteboard
	}

	func open(url: URL) {
		workspace.open(url)
	}

	func reveal(url: URL) {
		workspace.activateFileViewerSelecting([url])
	}

	func copy(text: String) {
		pasteboard.clearContents()
		pasteboard.setString(text, forType: .string)
	}

	func copy(pngData: Data) {
		pasteboard.clearContents()
		pasteboard.setData(pngData, forType: .png)
	}

	@MainActor
	func saveImage(pngData: Data, suggestedFileName: String) async throws -> URL? {
		let panel = NSSavePanel()
		panel.nameFieldStringValue = suggestedFileName
		panel.allowedContentTypes = [.png]
		let response = await panel.begin()
		guard response == .OK,
			let fileURL = panel.url
		else {
			return nil
		}
		try pngData.write(to: fileURL, options: .atomic)
		return fileURL
	}

	@MainActor
	func saveText(text: String, suggestedFileName: String) async throws -> URL? {
		let panel = NSSavePanel()
		panel.nameFieldStringValue = suggestedFileName
		let markdownType = UTType(filenameExtension: "md") ?? .plainText
		panel.allowedContentTypes = [markdownType]
		let response = await panel.begin()
		guard response == .OK,
			let fileURL = panel.url
		else {
			return nil
		}
		try text.write(to: fileURL, atomically: true, encoding: .utf8)
		return fileURL
	}

	@MainActor
	func saveData(_ data: Data, suggestedFileName: String, contentType: UTType) async throws -> URL? {
		let panel = NSSavePanel()
		panel.nameFieldStringValue = suggestedFileName
		panel.allowedContentTypes = [contentType]
		let response = await panel.begin()
		guard response == .OK,
			let fileURL = panel.url
		else {
			return nil
		}
		try data.write(to: fileURL, options: .atomic)
		return fileURL
	}

	@MainActor
	func chooseSaveLocation(suggestedFileName: String, contentType: UTType) async -> URL? {
		let panel = NSSavePanel()
		panel.nameFieldStringValue = suggestedFileName
		panel.allowedContentTypes = [contentType]
		let response = await panel.begin()
		return response == .OK ? panel.url : nil
	}

	@MainActor
	func chooseFolder(prompt: String, startingAt startingURL: URL?) async -> URL? {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.canCreateDirectories = true
		panel.allowsMultipleSelection = false
		panel.prompt = prompt
		panel.directoryURL = startingURL
		let response = await panel.begin()
		return response == .OK ? panel.url : nil
	}

	@MainActor
	func chooseFile(prompt: String, contentTypes: [UTType]) async -> URL? {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		panel.allowedContentTypes = contentTypes
		panel.prompt = prompt
		let response = await panel.begin()
		return response == .OK ? panel.url : nil
	}
}
