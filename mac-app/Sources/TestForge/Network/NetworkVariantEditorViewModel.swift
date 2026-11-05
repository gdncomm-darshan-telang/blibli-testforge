import Combine
import Foundation

enum NetworkEditorPhase: Equatable {
	case editing
	case saving
	case failed(String)
}

struct NetworkVariantEditorActions {
	let finish: (_ message: String) -> Void
	let cancel: () -> Void
}

/// One answer of one rule, as fields: kind, status, delay, body (JSON-checked), plus copy, delete and time-shift.
/// Saving a copy keeps the captured original — the safe default when an edit is an experiment.
@MainActor
final class NetworkVariantEditorViewModel: ObservableObject, Identifiable {
	@Published var name: String
	@Published var kind: NetworkVariantKind
	@Published var statusCodeText: String
	@Published var delayText: String
	@Published var body: String
	@Published var failure: NetworkFailureKind
	@Published var copyName: String
	@Published var shiftSecondsText = "30"
	@Published var selectedAnchorPath: String?
	@Published private(set) var phase: NetworkEditorPhase = .editing
	@Published private(set) var timestamps: NetworkSectionState<[LensTimestamp]> = .notLoaded

	let id: String
	let endpoint: String
	let isActive: Bool
	let isEditable: Bool

	private let ruleId: String
	private let headers: [String: String]
	private let service: NetworkRuleEditing
	private let actions: NetworkVariantEditorActions
	private var workTask: Task<Void, Never>?

	/// Nil when the fields can be saved; otherwise the reason, shown under the form.
	var validationMessage: String? {
		if !isEditable {
			return String(localized: "This answer has several steps — edit it in NetworkLens")
		}
		if name.trimmingCharacters(in: .whitespaces).isEmpty {
			return String(localized: "Give the answer a name")
		}
		guard kind == .respond else {
			return nil
		}
		guard let statusCode = Int(statusCodeText),
			(100...599).contains(statusCode)
		else {
			return String(localized: "Status must be a number from 100 to 599")
		}
		return jsonProblem
	}

	var canSave: Bool {
		validationMessage == nil && phase != .saving
	}

	init(service: NetworkRuleEditing, context: NetworkVariantEditorContext, actions: NetworkVariantEditorActions) {
		let variant = context.variant
		self.service = service
		self.actions = actions
		id = variant.id
		ruleId = context.ruleId
		endpoint = context.endpoint
		isActive = context.isActive
		isEditable = variant.isEditable
		headers = variant.headers.isEmpty ? ["Content-Type": "application/json"] : variant.headers
		name = variant.name
		kind = variant.kind ?? .respond
		statusCodeText = String(variant.statusCode)
		delayText = variant.delay > 0 ? String(Int(variant.delay)) : "0"
		body = variant.body
		failure = variant.failure ?? .timedOut
		copyName = String(localized: "\(variant.name) copy")
	}

	deinit {
		workTask?.cancel()
	}

	func save() {
		let fields = currentFields(name: name)
		run(done: String(localized: "Saved “\(name)”")) { [ruleId, id] service in
			try await service.editVariant(ruleId: ruleId, variantId: id, fields: fields)
		}
	}

	func saveAsCopy() {
		let copyTitle = copyName.trimmingCharacters(in: .whitespaces)
		let fields = currentFields(name: copyTitle)
		run(done: String(localized: "Saved as “\(copyTitle)” — choose it on the rule to use it")) { [ruleId, id] service in
			let copyId = try await service.copyVariant(ruleId: ruleId, fromVariantId: id, name: copyTitle)
			return try await service.editVariant(ruleId: ruleId, variantId: copyId, fields: fields)
		}
	}

	func delete() {
		run(done: String(localized: "Deleted “\(name)”")) { [ruleId, id] service in
			try await service.deleteVariant(ruleId: ruleId, variantId: id)
		}
	}

	func cancel() {
		actions.cancel()
	}

	func loadTimestamps() {
		guard kind == .respond else {
			return
		}
		timestamps = .loading
		workTask?.cancel()
		workTask = Task { [weak self] in
			guard let self else {
				return
			}
			do {
				let found = try await service.timestamps(ruleId: ruleId, variantId: id)
				timestamps = found.isEmpty ? .empty(String(localized: "No timestamps in this body")) : .loaded(found)
				selectedAnchorPath = selectedAnchorPath ?? found.first?.path
			} catch {
				timestamps = .failed(error.localizedDescription)
			}
		}
	}

	/// Every timestamp moves by one offset so the chosen one lands that many seconds from now; gaps stay as captured.
	func timeShift() {
		guard let anchorPath = selectedAnchorPath,
			let seconds = Int(shiftSecondsText)
		else {
			phase = .failed(String(localized: "Pick a timestamp and a whole number of seconds"))
			return
		}
		let shift = LensTimeShift(anchorPath: anchorPath, inSeconds: seconds)
		run(done: String(localized: "\(anchorPath) now lands \(seconds) s from now")) { [ruleId, id] service in
			try await service.timeShift(ruleId: ruleId, variantId: id, shift: shift)
		}
	}

	private var jsonProblem: String? {
		let isJSON = headers.contains { $0.key.lowercased() == "content-type" && $0.value.lowercased().contains("json") }
		let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
		guard isJSON,
			!trimmed.isEmpty
		else {
			return nil
		}
		let data = Data(trimmed.utf8)
		do {
			_ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
			return nil
		} catch {
			return String(localized: "Body is not valid JSON: \(error.localizedDescription)")
		}
	}

	private func currentFields(name: String) -> LensVariantFields {
		LensVariantFields(
			name: name.trimmingCharacters(in: .whitespaces),
			kind: kind.rawValue,
			statusCode: Int(statusCodeText) ?? 200,
			delay: Double(delayText) ?? 0,
			body: body,
			failure: kind == .fail ? failure.rawValue : nil,
			headers: headers
		)
	}

	private func run(done: String, work: @escaping (_ service: NetworkRuleEditing) async throws -> LensWriteResult) {
		phase = .saving
		workTask?.cancel()
		workTask = Task { [weak self] in
			guard let self else {
				return
			}
			do {
				let result = try await work(service)
				let message = NetworkConsoleMapper.writeMessage(result, done: done)
				phase = .editing
				actions.finish(message)
			} catch {
				phase = .failed(error.localizedDescription)
			}
		}
	}
}
