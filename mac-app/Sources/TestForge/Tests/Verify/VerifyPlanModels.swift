import Foundation

/// `POST /api/verify/plan` (D-196): the loaded cases whose recordings cover a diff, and the changed code none covers.
struct VerifyPlan: Decodable, Equatable {
	let range: String
	let changedFileCount: Int
	let changedAppFiles: [String]
	let cases: [VerifyCase]
	let uncoveredFiles: [String]
	let isSharedChange: Bool

	private enum CodingKeys: String, CodingKey {
		case range
		case changedFileCount
		case changedAppFiles
		case cases
		case uncoveredFiles
		case isSharedChange
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		range = (try? container.decodeIfPresent(String.self, forKey: .range)) ?? ""
		changedFileCount = (try? container.decodeIfPresent(Int.self, forKey: .changedFileCount)) ?? 0
		changedAppFiles = (try? container.decodeIfPresent([String].self, forKey: .changedAppFiles)) ?? []
		cases = (try? container.decodeIfPresent([VerifyCase].self, forKey: .cases)) ?? []
		uncoveredFiles = (try? container.decodeIfPresent([String].self, forKey: .uncoveredFiles)) ?? []
		isSharedChange = (try? container.decodeIfPresent(Bool.self, forKey: .isSharedChange)) ?? false
	}
}

struct VerifyCase: Decodable, Equatable, Identifiable {
	let caseId: String
	let macroName: String
	let files: [String]

	var id: String { caseId }

	var filesText: String {
		files.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
	}

	private enum CodingKeys: String, CodingKey {
		case caseId
		case macroName
		case files
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		caseId = (try? container.decodeIfPresent(String.self, forKey: .caseId)) ?? ""
		macroName = (try? container.decodeIfPresent(String.self, forKey: .macroName)) ?? ""
		files = (try? container.decodeIfPresent([String].self, forKey: .files)) ?? []
	}
}

enum VerifyChangesState: Equatable {
	case hidden
	case choosing
	case loading
	case loaded(VerifyPlan)
	case failed(message: String)
}
