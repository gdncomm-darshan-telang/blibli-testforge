import Foundation
import UniformTypeIdentifiers

struct BundleCaseMockRowModel: Equatable, Identifiable {
	let id: String
	let caseText: String
	let mocksText: String
	let canArm: Bool
}

struct BundleImportModel: Equatable {
	let title: String
	let facts: [ResultFactModel]
	let codeMessage: String
	let isCodeMatch: Bool
	let conflictText: String?
	let warnings: [String]
	let replayButtonTitle: String
	let canReplay: Bool
	let mockRows: [BundleCaseMockRowModel]
}

enum BundleImportState: Equatable {
	case idle
	case inspecting
	case preview(BundleImportModel)
	case importing
	case imported(BundleImportModel)
	case replaying
	case failed(message: String)
}

/// D-162 import flow: pick a bundle, preview what it adds, install it, then replay its recorded cases without Claude.
@MainActor
final class BundleImportViewModel: ObservableObject {
	@Published private(set) var state: BundleImportState = .idle
	@Published private(set) var armMessage: String?

	private let service: BundleActing
	private let desktop: DesktopActing
	private var fileURL: URL?
	private var bundleId: String?
	private var task: Task<Void, Never>?

	var isSheetPresented: Bool {
		state != .idle
	}

	init(service: BundleActing, desktop: DesktopActing) {
		self.service = service
		self.desktop = desktop
	}

	deinit {
		task?.cancel()
	}

	func chooseBundle() {
		let service = service
		let desktop = desktop
		task?.cancel()
		task = Task { [weak self] in
			let url = await desktop.chooseFile(prompt: String(localized: "Import bundle"), contentTypes: [.json])
			guard let url else {
				return
			}
			self?.fileURL = url
			self?.state = .inspecting
			do {
				let preview = try await service.inspectBundle(at: url)
				self?.state = .preview(BundleImportMapper.model(for: preview, isImported: false))
			} catch {
				self?.state = .failed(message: error.localizedDescription)
			}
		}
	}

	/// `replacesDiffering` overwrites the local macros, elements and mocks that differ from the bundle's.
	func importBundle(replacesDiffering: Bool) {
		guard let fileURL else {
			return
		}
		let service = service
		state = .importing
		task?.cancel()
		task = Task { [weak self] in
			do {
				let result = try await service.importBundle(at: fileURL, overwrite: replacesDiffering)
				self?.bundleId = result.bundle.id
				let model = BundleImportMapper.model(for: result, isImported: true, hasReplacedDiffering: replacesDiffering)
				self?.state = .imported(model)
			} catch {
				self?.state = .failed(message: error.localizedDescription)
			}
		}
	}

	/// The batch then shows in the run panel like any other; the sheet closes.
	func replay() {
		guard let bundleId else {
			return
		}
		let service = service
		state = .replaying
		task?.cancel()
		task = Task { [weak self] in
			do {
				try await service.replayBundle(id: bundleId)
				self?.close()
			} catch {
				self?.state = .failed(message: error.localizedDescription)
			}
		}
	}

	/// Leaves the sheet open, so several cases can be set up one after another.
	func armMocks(caseId: String) {
		guard let bundleId else {
			return
		}
		let service = service
		armMessage = String(localized: "Switching on case \(caseId)'s mocks…")
		task?.cancel()
		task = Task { [weak self] in
			do {
				try await service.armCase(bundleId: bundleId, caseId: caseId)
				self?.armMessage = String(localized: "Case \(caseId)'s mocks are on — test it on the simulator.")
			} catch {
				self?.armMessage = error.localizedDescription
			}
		}
	}

	func close() {
		task?.cancel()
		armMessage = nil
		state = .idle
	}
}

enum BundleImportMapper {
	static func model(for preview: BundlePreview, isImported: Bool, hasReplacedDiffering: Bool = false) -> BundleImportModel {
		let bundle = preview.bundle
		let plan = preview.plan
		var facts = [
			ResultFactModel(id: "cases", label: String(localized: "Cases"), value: casesText(bundle: bundle, plan: plan)),
			ResultFactModel(id: "code", label: String(localized: "Tested code"), value: codeText(bundle: bundle)),
			ResultFactModel(id: "adds", label: addsLabel(isImported: isImported), value: addsText(plan: plan, isImported: isImported)),
		]
		if let caseImport = preview.caseImport {
			facts.append(ResultFactModel(id: "document", label: String(localized: "Test document"), value: documentText(caseImport: caseImport)))
		}
		if let costUsd = bundle.costUsd {
			facts.append(ResultFactModel(id: "saved", label: String(localized: "Claude spend it saves"), value: String(format: "$%.2f", costUsd)))
		}
		if !plan.credentials.isEmpty {
			facts.append(ResultFactModel(id: "logins", label: String(localized: "Logins it types"), value: plan.credentials.joined(separator: ", ")))
		}
		return BundleImportModel(
			title: bundle.title,
			facts: facts,
			codeMessage: plan.codeMessage,
			isCodeMatch: plan.codeState == .match,
			conflictText: hasReplacedDiffering ? nil : conflictText(plan: plan, isImported: isImported),
			warnings: plan.warnings,
			replayButtonTitle: String(localized: "Replay \(bundle.replayableCount) case(s) without Claude"),
			canReplay: bundle.replayableCount > 0,
			mockRows: mockRows(plan: plan, isImported: isImported)
		)
	}

	/// Arming needs the imported bundle; cases with a recording arm their own mocks when replayed.
	private static func mockRows(plan: BundlePlan, isImported: Bool) -> [BundleCaseMockRowModel] {
		plan.caseMocks.map { entry in
			let mocksText = entry.mocks.map(mockText).joined(separator: "\n")
			let recordingText = entry.hasMacro ? String(localized: " · recorded") : ""
			return BundleCaseMockRowModel(
				id: entry.caseId,
				caseText: String(localized: "Case \(entry.caseId)") + recordingText,
				mocksText: mocksText,
				canArm: isImported && entry.mocks.contains { $0.variant != nil }
			)
		}
	}

	private static func mockText(_ mock: BundleCaseMock) -> String {
		let endpointName = mock.endpoint.split(separator: "/").last.map(String.init) ?? mock.endpoint
		if let variant = mock.variant {
			return "\(endpointName) → \(variant)"
		}
		guard !mock.candidates.isEmpty else {
			return String(localized: "\(endpointName) → unknown response")
		}
		return String(localized: "\(endpointName) → one of \(mock.candidates.joined(separator: ", "))")
	}

	private static func addsLabel(isImported: Bool) -> String {
		isImported ? String(localized: "Added") : String(localized: "Adds")
	}

	private static func casesText(bundle: BundleSummary, plan: BundlePlan) -> String {
		let judged = plan.needsJudgmentCount
		let judgedText = judged > 0 ? String(localized: " · \(judged) need a person or Claude") : ""
		return String(localized: "\(bundle.caseCount) · \(bundle.replayableCount) replay without Claude") + judgedText
	}

	private static func documentText(caseImport: BundleCaseImport) -> String {
		guard caseImport.isMerged else {
			return String(localized: "Loaded as the test document")
		}
		return String(localized: "\(caseImport.addedCount) new case(s) added to the loaded document; its other cases stay")
	}

	private static func codeText(bundle: BundleSummary) -> String {
		let branch = bundle.branch ?? "—"
		let commit = bundle.commit ?? "—"
		let localText = bundle.hasLocalChanges ? String(localized: " (with uncommitted changes)") : ""
		return "\(branch) @ \(commit)\(localText)"
	}

	private static func addsText(plan: BundlePlan, isImported: Bool) -> String {
		guard isImported,
			let written = plan.written
		else {
			return String(localized: "\(plan.addedMacroCount) macro(s), \(plan.addedElementCount) element(s), \(plan.addedMockCount) mock(s)")
		}
		return String(localized: "\(written.macroPaths.count) macro(s), \(written.elementCount) element(s), \(written.mockFiles.count) mock(s)")
	}

	private static func conflictText(plan: BundlePlan, isImported: Bool) -> String? {
		guard plan.conflictCount > 0 else {
			return nil
		}
		return isImported
			? String(localized: "\(plan.conflictCount) item(s) differ from yours; the ones you kept are what the replay uses.")
			: String(localized: "\(plan.conflictCount) macro(s), element(s) or mock(s) differ from yours. Import keeps yours; Replace uses the bundle's.")
	}
}
