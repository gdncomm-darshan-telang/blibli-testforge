import Foundation

struct MacroRowModel: Equatable, Identifiable {
	let id: String
	let name: String
	let subtitle: String
	let isUsingMocks: Bool
}

struct MacroStepModel: Equatable, Identifiable {
	let id: String
	let number: Int
	let action: String
	let text: String
	let hasWeakTarget: Bool
}

struct MacroReplayFeedback: Equatable {
	let notice: String?
	let isQueuing: Bool
}

struct MacroDetailModel: Equatable {
	let macroId: String
	let name: String
	let description: String
	let path: String
	let steps: [MacroStepModel]
}

enum RecordedStepsState: Equatable {
	case notLoaded
	case loading
	case loaded([MacroRowModel])
	case failed(String)
}

enum MacroDetailState: Equatable {
	case notSelected
	case loading
	case loaded(MacroDetailModel)
	case failed(String)
}

/// Recorded steps panel: the saved macros, one macro's steps, the lint check, and Replay into the device lane.
/// Whole-class `@MainActor`: every method only maps service answers to published state.
@MainActor
final class RecordedStepsViewModel: ObservableObject {
	@Published private(set) var state: RecordedStepsState = .notLoaded
	@Published private(set) var detail: MacroDetailState = .notSelected
	@Published private(set) var lintSummary: String?
	@Published private(set) var actionMessage: String?
	@Published private(set) var replayNotice: String?
	@Published private(set) var isQueuingReplay = false

	@Published var searchText = "" {
		didSet {
			applyFilter()
		}
	}

	@Published var selectedMacroId: String? {
		didSet {
			loadDetail()
		}
	}

	private let service: MacroActing
	private var macros: [MacroSummary] = []
	private var loadTask: Task<Void, Never>?
	private var detailTask: Task<Void, Never>?
	private var replayTask: Task<Void, Never>?

	var replayFeedback: MacroReplayFeedback {
		MacroReplayFeedback(notice: replayNotice, isQueuing: isQueuingReplay)
	}

	init(service: MacroActing) {
		self.service = service
	}

	deinit {
		loadTask?.cancel()
		detailTask?.cancel()
		replayTask?.cancel()
	}

	func loadIfNeeded() {
		guard state == .notLoaded else {
			return
		}
		reload()
	}

	/// The lint runs with the list so a broken macro shows before someone replays it.
	func reload() {
		loadTask?.cancel()
		state = .loading
		let service = service
		loadTask = Task { [weak self] in
			do {
				let macros = try await service.macros()
				let lintSummary = await Self.lintSummary(service: service)
				self?.finishLoading(macros: macros, lintSummary: lintSummary)
			} catch {
				self?.state = .failed(error.localizedDescription)
			}
		}
	}

	func replaySelected() {
		guard !isQueuingReplay,
			case .loaded(let model) = detail
		else {
			return
		}
		replayNotice = nil
		isQueuingReplay = true
		let service = service
		let macroId = model.macroId
		let name = model.name
		replayTask = Task { [weak self] in
			do {
				try await service.replay(macroId: macroId)
				self?.replayNotice = String(localized: "Queued “\(name)”. Watch it in Tests › Live steps or the console.")
			} catch {
				self?.actionMessage = error.localizedDescription
			}
			self?.isQueuingReplay = false
		}
	}

	func dismissMessage() {
		actionMessage = nil
	}

	/// A failed check still shows the list, with the reason in place of the summary.
	private static func lintSummary(service: MacroActing) async -> String {
		do {
			let report = try await service.lint()
			return RecordedStepsMapper.lintSummary(report: report)
		} catch {
			return String(localized: "Couldn't run the check: \(error.localizedDescription)")
		}
	}

	private func finishLoading(macros: [MacroSummary], lintSummary: String) {
		self.macros = macros.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
		self.lintSummary = lintSummary
		state = .loaded(filteredRows())
	}

	private func applyFilter() {
		guard case .loaded = state else {
			return
		}
		state = .loaded(filteredRows())
	}

	private func filteredRows() -> [MacroRowModel] {
		let query = searchText.trimmingCharacters(in: .whitespaces)
		let matching = query.isEmpty ? macros : macros.filter { RecordedStepsMapper.matches(macro: $0, query: query) }
		return matching.map(RecordedStepsMapper.row(macro:))
	}

	private func loadDetail() {
		detailTask?.cancel()
		replayNotice = nil
		let summary = macros.first { $0.id == selectedMacroId }
		guard let summary else {
			detail = .notSelected
			return
		}
		detail = .loading
		let service = service
		detailTask = Task { [weak self] in
			do {
				let macroDetail = try await service.detail(macroId: summary.id)
				self?.detail = .loaded(RecordedStepsMapper.detail(summary: summary, detail: macroDetail))
			} catch {
				guard !Task.isCancelled else {
					return
				}
				self?.detail = .failed(error.localizedDescription)
			}
		}
	}
}

enum RecordedStepsMapper {
	static func row(macro: MacroSummary) -> MacroRowModel {
		let anchorText = macro.targetedCount > 0 ? String(localized: "\(macro.anchoredCount) of \(macro.targetedCount) steps found by id") : ""
		let parts = [macro.testCases.joined(separator: ", "), anchorText].filter { !$0.isEmpty }
		let kindText = kindTitle(kind: macro.kind)
		let subtitle = ([kindText] + parts).joined(separator: " · ")
		return MacroRowModel(id: macro.id, name: macro.name, subtitle: subtitle, isUsingMocks: macro.isUsingMocks)
	}

	static func matches(macro: MacroSummary, query: String) -> Bool {
		let haystack = [macro.name, macro.id, macro.path] + macro.testCases
		return haystack.contains { $0.localizedCaseInsensitiveContains(query) }
	}

	static func detail(summary: MacroSummary, detail: MacroDetail) -> MacroDetailModel {
		let steps = detail.steps.enumerated().map { index, step in
			MacroStepModel(id: step.id, number: index + 1, action: step.action, text: step.text, hasWeakTarget: step.quality == "label")
		}
		return MacroDetailModel(macroId: summary.id, name: summary.name, description: detail.description, path: summary.path, steps: steps)
	}

	static func lintSummary(report: MacroLintReport) -> String {
		if report.errors.isEmpty && report.warnings.isEmpty {
			return String(localized: "All \(report.macroCount) recordings pass the check.")
		}
		return String(localized: "Check: \(report.errors.count) errors, \(report.warnings.count) warnings across \(report.macroCount) recordings.")
	}

	private static func kindTitle(kind: String) -> String {
		switch kind {
			case "routine":
				return String(localized: "Shared step")
			case "bug-verify":
				return String(localized: "Bug check")
			default:
				return String(localized: "Test case")
		}
	}
}
