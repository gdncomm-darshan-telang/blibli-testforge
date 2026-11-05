import Combine
import Foundation

/// Tests › Post to Jira (D-193): the case's ticket from the document and its result comment, edited, then posted on confirm.
/// Whole-class `@MainActor`: it holds one draft and forwards Post.
@MainActor
final class JiraPostViewModel: ObservableObject {
	@Published private(set) var state: JiraPostState = .hidden
	@Published private(set) var tickets: [JiraTicket] = []
	@Published private(set) var historyText: String?
	@Published var ticketKey = ""
	@Published var comment = ""
	@Published var isConfirmationShown = false

	private let service: TestCaseActing
	private var caseId: String?
	private var task: Task<Void, Never>?

	init(service: TestCaseActing) {
		self.service = service
	}

	deinit {
		task?.cancel()
	}

	var isShown: Bool {
		state != .hidden
	}

	var canPost: Bool {
		state == .editing && ticketKey.range(of: #"^[A-Z][A-Z0-9]{1,9}-\d{1,7}$"#, options: .regularExpression) != nil
			&& !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	func begin(caseId: String) {
		self.caseId = caseId
		state = .loading
		let service = service
		task?.cancel()
		task = Task { [weak self] in
			do {
				let draft = try await service.jiraDraft(caseId: caseId)
				self?.apply(draft: draft)
			} catch {
				self?.state = .failed(message: error.localizedDescription)
			}
		}
	}

	func requestPost() {
		guard canPost else {
			return
		}
		isConfirmationShown = true
	}

	/// The only path that writes to Jira, reached from the confirmation dialog.
	func confirmPost() {
		isConfirmationShown = false
		guard canPost,
			let caseId
		else {
			return
		}
		state = .posting
		let service = service
		let key = ticketKey
		let text = comment
		task = Task { [weak self] in
			do {
				try await service.postJira(caseId: caseId, key: key, comment: text)
				self?.state = .posted(key: key)
			} catch {
				self?.state = .failed(message: error.localizedDescription)
			}
		}
	}

	func dismiss() {
		task?.cancel()
		state = .hidden
	}

	private func apply(draft: JiraDraft) {
		tickets = draft.tickets
		ticketKey = draft.tickets.first?.key ?? ""
		comment = draft.comment
		historyText = draft.posts.first(where: \.isPosted).map { post in
			let dateText = post.postedAt?.formatted(date: .abbreviated, time: .shortened) ?? ""
			return String(localized: "Last posted to \(post.key) \(dateText)")
		}
		state = .editing
	}
}
