import Foundation

struct CommandOutput: Equatable {
	let status: Int32
	let output: String
	let errorOutput: String

	var isSuccess: Bool {
		status == 0
	}

	/// The line worth showing a person: the error when it failed, else the output.
	/// Tools like `defaults` prefix errors with a timestamp and process id, which only hide the message.
	var summary: String {
		let text = isSuccess ? output : (errorOutput.isEmpty ? output : errorOutput)
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		let logPrefix = #"^\d{4}-\d{2}-\d{2} [\d:.]+ \w+\[[\d:]+\] "#
		return trimmed.replacingOccurrences(of: logPrefix, with: "", options: .regularExpression)
	}
}

struct CommandRequest {
	let executable: String
	let arguments: [String]
}

protocol CommandRunning {
	func run(_ request: CommandRequest) async throws -> CommandOutput
}

/// Runs a tool and echoes the command and its result into the console, so every button's real effect is visible.
struct ProcessCommandRunner: CommandRunning {
	let console: ConsoleLogging?

	func run(_ request: CommandRequest) async throws -> CommandOutput {
		let commandLine = ([request.executable] + request.arguments).joined(separator: " ")
		console?.append(text: "$ \(commandLine)", source: .app)
		let process = Process()
		process.executableURL = URL(fileURLWithPath: request.executable)
		process.arguments = request.arguments
		let outputPipe = Pipe()
		let errorPipe = Pipe()
		process.standardOutput = outputPipe
		process.standardError = errorPipe
		try process.run()
		let output = await Self.read(pipe: outputPipe)
		let errorOutput = await Self.read(pipe: errorPipe)
		await Task.detached {
			process.waitUntilExit()
		}.value
		let result = CommandOutput(status: process.terminationStatus, output: output, errorOutput: errorOutput)
		let outcome = result.isSuccess ? "ok" : "failed (\(result.status)): \(result.summary)"
		console?.append(text: "  → \(outcome)", source: .app)
		return result
	}

	/// Read on a background thread so a large output can't fill the pipe and stall the tool.
	private static func read(pipe: Pipe) async -> String {
		await Task.detached {
			let data = pipe.fileHandleForReading.readDataToEndOfFile()
			return String(data: data, encoding: .utf8) ?? ""
		}.value
	}
}
