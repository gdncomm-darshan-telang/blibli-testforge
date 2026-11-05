import Combine
import Foundation

/// Get Ready › Prerequisites (D-190): each tool, plugin and MCP server with its state and the step that fixes it.
/// Whole-class `@MainActor`: it only maps one small report to rows and copies a command.
@MainActor
final class PrerequisitesViewModel: ObservableObject {
	@Published private(set) var state: PrerequisitesState = .loading
	@Published var isShown = false
	@Published private(set) var isRefreshing = false

	private let service: PrerequisitesListing
	private let desktop: DesktopActing
	private var loadTask: Task<Void, Never>?

	init(service: PrerequisitesListing, desktop: DesktopActing) {
		self.service = service
		self.desktop = desktop
	}

	deinit {
		loadTask?.cancel()
	}

	func show() {
		isShown = true
		load(isRefreshing: false)
	}

	func refresh() {
		guard !isRefreshing else {
			return
		}
		isRefreshing = true
		load(isRefreshing: true)
	}

	func copy(howTo: String) {
		desktop.copy(text: howTo)
	}

	private func load(isRefreshing: Bool) {
		if case .failed = state {
			state = .loading
		}
		let service = service
		loadTask?.cancel()
		loadTask = Task { [weak self] in
			defer {
				if !Task.isCancelled {
					self?.isRefreshing = false
				}
			}
			do {
				let report = try await service.report(isRefreshing: isRefreshing)
				guard !Task.isCancelled else {
					return
				}
				let checkedText = report.checkedAt.map { String(localized: "Checked \($0.formatted(date: .omitted, time: .shortened))") } ?? ""
				self?.state = .loaded(report.items.map { Self.row(for: $0) }, checkedText: checkedText)
			} catch {
				self?.state = .failed(message: error.localizedDescription)
			}
		}
	}

	private static func row(for item: PrerequisiteItem) -> PrerequisiteRowModel {
		let groupTitle: String
		switch item.kind {
			case "plugin":
				groupTitle = String(localized: "Claude Code plugin")
			case "mcp":
				groupTitle = String(localized: "MCP servers")
			default:
				groupTitle = String(localized: "Tools")
		}
		let tone: VerdictTone = item.isOk ? .passed : (item.isRequired ? .failed : .neutral)
		let statusSymbol = item.isOk ? "checkmark.circle.fill" : (item.isRequired ? "xmark.circle.fill" : "exclamationmark.circle")
		let detail = item.isRequired || item.isOk ? item.detail : String(localized: "\(item.detail) · optional")
		return PrerequisiteRowModel(
			id: item.id,
			label: item.label,
			groupTitle: groupTitle,
			detail: detail,
			statusSymbol: statusSymbol,
			tone: tone,
			howTo: item.isOk || item.howTo.isEmpty ? nil : item.howTo
		)
	}
}
