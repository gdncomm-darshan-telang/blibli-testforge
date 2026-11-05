import Foundation

enum CodeSource: String, CaseIterable, Identifiable {
	case github
	case local

	var id: String { rawValue }

	var title: LocalizedStringResource {
		switch self {
			case .github:
				return "A GitHub branch"
			case .local:
				return "My working copy"
		}
	}
}

struct CodeRepository: Decodable, Equatable, Identifiable {
	let name: String
	let path: String
	let branch: String
	let isDirty: Bool

	var id: String { path }

	private enum CodingKeys: String, CodingKey {
		case name
		case path
		case branch
		case isDirty
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
		path = (try? container.decodeIfPresent(String.self, forKey: .path)) ?? ""
		branch = (try? container.decodeIfPresent(String.self, forKey: .branch)) ?? ""
		isDirty = (try? container.decodeIfPresent(Bool.self, forKey: .isDirty)) ?? false
	}
}

struct CodeRepositoryList: Decodable {
	let repos: [CodeRepository]

	private enum CodingKeys: String, CodingKey {
		case repos
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		repos = (try? container.decodeIfPresent([CodeRepository].self, forKey: .repos)) ?? []
	}
}

struct CodeBranch: Decodable, Equatable, Identifiable {
	let name: String
	let sha: String
	let subject: String
	let committedAt: Date?

	/// False for a branch only on this Mac: a GitHub prepare can't fetch it, a working-copy snapshot can.
	let isOnGitHub: Bool

	let isNewOnGitHub: Bool

	/// D-200: false for a GitHub-only branch; switching to it creates a local tracking branch.
	let isLocal: Bool

	var id: String { name }

	private enum CodingKeys: String, CodingKey {
		case name
		case sha
		case subject
		case committedAt = "date"
		case isOnGitHub = "onGitHub"
		case isNewOnGitHub = "isNew"
		case isLocal
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
		sha = (try? container.decodeIfPresent(String.self, forKey: .sha)) ?? ""
		subject = (try? container.decodeIfPresent(String.self, forKey: .subject)) ?? ""
		let dateText = try? container.decodeIfPresent(String.self, forKey: .committedAt)
		committedAt = dateText.flatMap { ISO8601DateFormatter().date(from: $0) }
		isOnGitHub = (try? container.decodeIfPresent(Bool.self, forKey: .isOnGitHub)) ?? false
		isNewOnGitHub = (try? container.decodeIfPresent(Bool.self, forKey: .isNewOnGitHub)) ?? false
		isLocal = (try? container.decodeIfPresent(Bool.self, forKey: .isLocal)) ?? false
	}
}

struct CodeBranchList: Decodable {
	let branches: [CodeBranch]

	private enum CodingKeys: String, CodingKey {
		case branches
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		branches = (try? container.decodeIfPresent([CodeBranch].self, forKey: .branches)) ?? []
	}
}

/// `/api/code/current`: what the QA copy holds, and whether the working copy moved on since.
struct PreparedCodeSummary: Decodable, Equatable {
	let branch: String
	let snapshotId: String
	let source: String
	let title: String
	let author: String
	let changedFileCount: Int
	let preparedAt: Date?
	let hasAppChanged: Bool
	let changedAppFiles: [String]

	private enum CodingKeys: String, CodingKey {
		case manifest
		case drift
	}

	private enum ManifestKeys: String, CodingKey {
		case branch
		case snapshotId
		case source
		case title
		case author
		case changedFileCount
		case preparedAt
	}

	private enum DriftKeys: String, CodingKey {
		case hasAppInputsChanged
		case appFiles
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let manifest = try container.nestedContainer(keyedBy: ManifestKeys.self, forKey: .manifest)
		branch = (try? manifest.decodeIfPresent(String.self, forKey: .branch)) ?? ""
		snapshotId = (try? manifest.decodeIfPresent(String.self, forKey: .snapshotId)) ?? ""
		source = (try? manifest.decodeIfPresent(String.self, forKey: .source)) ?? ""
		title = (try? manifest.decodeIfPresent(String.self, forKey: .title)) ?? ""
		author = (try? manifest.decodeIfPresent(String.self, forKey: .author)) ?? ""
		changedFileCount = (try? manifest.decodeIfPresent(Int.self, forKey: .changedFileCount)) ?? 0
		let preparedText = try? manifest.decodeIfPresent(String.self, forKey: .preparedAt)
		preparedAt = preparedText.flatMap { ServerDate.parse(text: $0) }
		let drift = try? container.nestedContainer(keyedBy: DriftKeys.self, forKey: .drift)
		hasAppChanged = (try? drift?.decodeIfPresent(Bool.self, forKey: .hasAppInputsChanged)) ?? false
		changedAppFiles = (try? drift?.decodeIfPresent([String].self, forKey: .appFiles)) ?? []
	}
}

struct PrepareJobStart: Decodable {
	let jobId: String

	private enum CodingKeys: String, CodingKey {
		case jobId
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		jobId = (try? container.decodeIfPresent(String.self, forKey: .jobId)) ?? ""
	}
}

struct PrepareJobResult: Decodable {
	let status: String
	let verdict: String

	private enum CodingKeys: String, CodingKey {
		case status
		case verdict
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		status = (try? container.decodeIfPresent(String.self, forKey: .status)) ?? ""
		verdict = (try? container.decodeIfPresent(String.self, forKey: .verdict)) ?? ""
	}
}

struct PrepareProgressLine: Identifiable, Equatable {
	enum Kind: Equatable {
		case doing
		case done
		case failed
	}

	let id: Int
	let text: String
	let kind: Kind
	let toolOutput: String?
}

enum PrepareCodePhase: Equatable {
	case loading
	case failed(message: String)
	case choosing
	case preparing
	case finished(message: String, isSuccess: Bool)
}
