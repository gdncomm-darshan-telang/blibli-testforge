import Foundation

/// `GET /api/testcases/:id/jira` (D-193): the case's tickets from the document and the comment its result would post.
struct JiraDraft: Decodable, Equatable {
	let caseId: String
	let tickets: [JiraTicket]
	let comment: String
	let posts: [JiraPostRecord]

	private enum CodingKeys: String, CodingKey {
		case caseId
		case tickets
		case comment
		case posts
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		caseId = (try? container.decodeIfPresent(String.self, forKey: .caseId)) ?? ""
		tickets = (try? container.decodeIfPresent([JiraTicket].self, forKey: .tickets)) ?? []
		comment = (try? container.decodeIfPresent(String.self, forKey: .comment)) ?? ""
		posts = (try? container.decodeIfPresent([JiraPostRecord].self, forKey: .posts)) ?? []
	}
}

struct JiraTicket: Decodable, Equatable, Identifiable {
	let key: String
	let url: URL?

	var id: String { key }

	private enum CodingKeys: String, CodingKey {
		case key
		case url
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		key = (try? container.decodeIfPresent(String.self, forKey: .key)) ?? ""
		url = (try? container.decodeIfPresent(String.self, forKey: .url)).flatMap { URL(string: $0) }
	}
}

struct JiraPostRecord: Decodable, Equatable {
	let key: String
	let postedAt: Date?
	let isPosted: Bool

	private enum CodingKeys: String, CodingKey {
		case key
		case postedAt = "at"
		case isPosted = "ok"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		key = (try? container.decodeIfPresent(String.self, forKey: .key)) ?? ""
		let postedText = try? container.decodeIfPresent(String.self, forKey: .postedAt)
		postedAt = postedText.flatMap { ServerDate.parse(text: $0) }
		isPosted = (try? container.decodeIfPresent(Bool.self, forKey: .isPosted)) ?? false
	}
}

enum JiraPostState: Equatable {
	case hidden
	case loading
	case editing
	case posting
	case posted(key: String)
	case failed(message: String)
}
