import Foundation

/// `GET /api/testcases/:id/media` (D-183): the case's proof files in the active test batch, oldest first.
struct TestCaseMediaList: Decodable {
	let urls: [URL]

	private enum CodingKeys: String, CodingKey {
		case files
	}

	private struct File: Decodable {
		let path: String?

		private enum CodingKeys: String, CodingKey {
			case path
		}

		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			path = try? container.decodeIfPresent(String.self, forKey: .path)
		}
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let files = (try? container.decodeIfPresent([File].self, forKey: .files)) ?? []
		urls = files.compactMap { $0.path }.map { URL(fileURLWithPath: $0) }
	}
}
