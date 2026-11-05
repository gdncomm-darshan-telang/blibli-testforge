import Foundation

/// One recorded demo video folder (D-164), as Reports › Demos lists it (D-177).
struct DemoRecording: Decodable, Equatable, Identifiable {
	let id: String
	let caseId: String
	let macroName: String
	let verdict: String?
	let recordedAt: Date?
	let videos: [DemoLanguage: URL]

	private enum CodingKeys: String, CodingKey {
		case folder
		case caseId
		case macroName
		case verdict
		case recordedAt
		case videos
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(String.self, forKey: .folder)
		caseId = (try? container.decodeIfPresent(String.self, forKey: .caseId)) ?? ""
		macroName = (try? container.decodeIfPresent(String.self, forKey: .macroName)) ?? caseId
		verdict = try? container.decodeIfPresent(String.self, forKey: .verdict)
		let recordedText = try? container.decodeIfPresent(String.self, forKey: .recordedAt)
		recordedAt = recordedText.flatMap { try? Date($0, strategy: .iso8601) }
		let paths = (try? container.decodeIfPresent([String: String?].self, forKey: .videos)) ?? [:]
		var videos: [DemoLanguage: URL] = [:]
		for language in DemoLanguage.allCases {
			if let path = paths[language.rawValue] ?? nil {
				videos[language] = URL(fileURLWithPath: path)
			}
		}
		self.videos = videos
	}

	var languages: [DemoLanguage] {
		DemoLanguage.allCases.filter { videos[$0] != nil }
	}
}

struct DemoRecordingList: Decodable {
	let recordings: [DemoRecording]

	private enum CodingKeys: String, CodingKey {
		case recordings
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		recordings = (try? container.decodeIfPresent([DemoRecording].self, forKey: .recordings)) ?? []
	}
}
