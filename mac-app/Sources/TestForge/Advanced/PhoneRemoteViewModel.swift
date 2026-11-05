import Foundation

enum PhoneRemoteOutcome: Equatable {
	case succeeded
	case warned(String)
	case failed(String)
}

struct PhoneRemoteResult: Equatable, Identifiable {
	let id: UUID
	let title: String
	let sentAt: Date
	let outcome: PhoneRemoteOutcome
	let output: String
}

enum PhoneRemoteSendState: Equatable {
	case idle
	case sending(title: String)
}

/// Phone remote panel: sends one driver command to the simulator and keeps the answers of this session.
/// Whole-class `@MainActor`: every method only builds the request and maps the answer to published state.
@MainActor
final class PhoneRemoteViewModel: ObservableObject {
	@Published private(set) var sendState: PhoneRemoteSendState = .idle
	@Published private(set) var history: [PhoneRemoteResult] = []
	@Published private(set) var hostText = ""
	@Published var selectedResultId: UUID?
	@Published var textValues: [String: String] = [:]
	@Published var toggleValues: [String: Bool] = [:]
	@Published var isRelaunchConfirmationShown = false

	@Published var selectedKind = DriverCommandCatalog.all.first?.kind ?? "" {
		didSet {
			textValues = [:]
			toggleValues = [:]
		}
	}

	let commands = DriverCommandCatalog.all

	private let service: DriverCommanding
	private let historyLimit = 20
	private var sendTask: Task<Void, Never>?
	private var hostTask: Task<Void, Never>?

	var selectedCommand: DriverCommandSpec? {
		commands.first { $0.kind == selectedKind }
	}

	var selectedResult: PhoneRemoteResult? {
		history.first { $0.id == selectedResultId } ?? history.first
	}

	var canSend: Bool {
		guard sendState == .idle,
			let command = selectedCommand
		else {
			return false
		}
		return command.fields.filter(\.isRequired).allSatisfy { !trimmedValue(field: $0.name).isEmpty }
	}

	init(service: DriverCommanding) {
		self.service = service
	}

	deinit {
		sendTask?.cancel()
		hostTask?.cancel()
	}

	func refreshHost() {
		hostTask?.cancel()
		let service = service
		hostTask = Task { [weak self] in
			let status = try? await service.host()
			self?.hostText = PhoneRemoteMapper.hostText(status: status)
		}
	}

	func requestSend() {
		guard canSend,
			let command = selectedCommand
		else {
			return
		}
		if command.needsConfirmation {
			isRelaunchConfirmationShown = true
		} else {
			send(command: command)
		}
	}

	func confirmRelaunch() {
		guard let command = selectedCommand else {
			return
		}
		send(command: command)
	}

	private func send(command: DriverCommandSpec) {
		let body = requestBody(command: command)
		sendState = .sending(title: command.title)
		let service = service
		sendTask = Task { [weak self] in
			do {
				let output = try await service.send(command: body)
				self?.record(title: command.title, output: output, failure: nil)
			} catch {
				self?.record(title: command.title, output: "", failure: error.localizedDescription)
			}
		}
	}

	private func record(title: String, output: String, failure: String?) {
		let outcome = failure.map(PhoneRemoteOutcome.failed) ?? PhoneRemoteMapper.outcome(output: output)
		let result = PhoneRemoteResult(id: UUID(), title: title, sentAt: Date(), outcome: outcome, output: output)
		history.insert(result, at: 0)
		history = Array(history.prefix(historyLimit))
		selectedResultId = result.id
		sendState = .idle
	}

	/// Empty optional fields are left out so the harness applies its own defaults.
	private func requestBody(command: DriverCommandSpec) -> [String: JSONValue] {
		var body: [String: JSONValue] = ["kind": .string(command.kind)]
		for field in command.fields {
			let value = trimmedValue(field: field.name)
			switch field.kind {
				case .text:
					if !value.isEmpty {
						body[field.name] = .string(value)
					}
				case .number:
					if let number = Double(value) {
						body[field.name] = .number(number)
					}
				case .toggle:
					if toggleValues[field.name] == true {
						body[field.name] = .bool(true)
					}
			}
		}
		return body
	}

	private func trimmedValue(field name: String) -> String {
		(textValues[name] ?? "").trimmingCharacters(in: .whitespaces)
	}
}

enum PhoneRemoteMapper {
	/// A 200 answer can still say the element wasn't there; same reading as the web Driver console.
	static func outcome(output: String) -> PhoneRemoteOutcome {
		let data = Data(output.utf8)
		guard case .object(let fields)? = try? JSONDecoder().decode(JSONValue.self, from: data) else {
			return .succeeded
		}
		if case .string(let message)? = fields["error"] {
			return .failed(message)
		}
		let warnings: [(String, String)] = [
			("found", String(localized: "Element not found")),
			("hittable", String(localized: "Element not hittable")),
			("exists", String(localized: "Element does not exist")),
			("pass", String(localized: "Assertion did not pass"))
		]
		let warning = warnings.first { fields[$0.0] == .bool(false) }
		return warning.map { .warned($0.1) } ?? .succeeded
	}

	static func hostText(status: DriverHostStatus?) -> String {
		guard let status,
			status.isReachable
		else {
			return String(localized: "No harness answering — start it from Get Ready.")
		}
		let host = status.hostedBy ?? String(localized: "the server")
		return String(localized: "Answered by \(host) · \(status.queuedCount) waiting")
	}
}
