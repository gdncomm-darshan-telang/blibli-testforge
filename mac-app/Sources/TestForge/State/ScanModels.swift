import Foundation

/// The `scan` slice (D-086): what scan mode sees on screen now and the screens marked so far.
struct ScanState: Decodable, Equatable {
	let isActive: Bool
	let isStopping: Bool
	let endedAt: Date?
	let outPath: String?
	let deviceName: String?
	let current: ScanCurrentScreen?
	let screens: [ScanMarkedScreen]
	let skipped: Int
	let pollError: String?
	let message: String?
	let fatal: String?

	private enum CodingKeys: String, CodingKey {
		case isActive
		case isStopping
		case endedAt
		case outPath = "out"
		case device
		case current
		case screens
		case skipped
		case pollError
		case message
		case fatal
	}

	private enum DeviceKeys: String, CodingKey {
		case deviceName
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		isActive = (try? container.decodeIfPresent(Bool.self, forKey: .isActive)) ?? false
		isStopping = (try? container.decodeIfPresent(Bool.self, forKey: .isStopping)) ?? false
		let endedText = try? container.decodeIfPresent(String.self, forKey: .endedAt)
		endedAt = endedText.flatMap { ServerDate.parse(text: $0) }
		outPath = try? container.decodeIfPresent(String.self, forKey: .outPath)
		let device = try? container.nestedContainer(keyedBy: DeviceKeys.self, forKey: .device)
		deviceName = try? device?.decodeIfPresent(String.self, forKey: .deviceName)
		current = try? container.decodeIfPresent(ScanCurrentScreen.self, forKey: .current)
		screens = (try? container.decodeIfPresent([ScanMarkedScreen].self, forKey: .screens)) ?? []
		skipped = (try? container.decodeIfPresent(Int.self, forKey: .skipped)) ?? 0
		pollError = try? container.decodeIfPresent(String.self, forKey: .pollError)
		message = try? container.decodeIfPresent(String.self, forKey: .message)
		fatal = try? container.decodeIfPresent(String.self, forKey: .fatal)
	}
}

struct ScanCurrentScreen: Decodable, Equatable {
	let changedAt: Date?
	let elementCount: Int
	let identifierCount: Int
	let identifiers: [String]
	/// The driver's dump stops at 20 000 characters; anything below the cut was not seen.
	let isTruncated: Bool

	/// Distinct trees since the scan started; far more than marks means screens went by unnamed.
	let distinctSeen: Int

	private enum CodingKeys: String, CodingKey {
		case changedAt
		case elementCount
		case identifierCount
		case identifiers
		case isTruncated
		case distinctSeen
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let changedText = try? container.decodeIfPresent(String.self, forKey: .changedAt)
		changedAt = changedText.flatMap { ScanCurrentScreen.parseScriptDate(text: $0) }
		elementCount = (try? container.decodeIfPresent(Int.self, forKey: .elementCount)) ?? 0
		identifierCount = (try? container.decodeIfPresent(Int.self, forKey: .identifierCount)) ?? 0
		identifiers = (try? container.decodeIfPresent([String].self, forKey: .identifiers)) ?? []
		isTruncated = (try? container.decodeIfPresent(Bool.self, forKey: .isTruncated)) ?? false
		distinctSeen = (try? container.decodeIfPresent(Int.self, forKey: .distinctSeen)) ?? 0
	}

	/// scan_mode.py writes whole seconds (`2026-10-14T01:51:45Z`), unlike the server's milliseconds.
	private static func parseScriptDate(text: String) -> Date? {
		let formatter = ISO8601DateFormatter()
		return formatter.date(from: text) ?? ServerDate.parse(text: text)
	}
}

struct ScanMarkedScreen: Decodable, Equatable, Identifiable {
	let name: String
	let variants: [ScanCapture]

	var id: String { name }

	private enum CodingKeys: String, CodingKey {
		case name
		case variants
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
		variants = (try? container.decodeIfPresent([ScanCapture].self, forKey: .variants)) ?? []
	}
}

struct ScanCapture: Decodable, Equatable {
	let elementCount: Int
	let identifierCount: Int
	let merged: Int
	let isComplete: Bool

	private enum CodingKeys: String, CodingKey {
		case elementCount
		case identifierCount
		case merged
		case isComplete
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		elementCount = (try? container.decodeIfPresent(Int.self, forKey: .elementCount)) ?? 0
		identifierCount = (try? container.decodeIfPresent(Int.self, forKey: .identifierCount)) ?? 0
		merged = (try? container.decodeIfPresent(Int.self, forKey: .merged)) ?? 0
		isComplete = (try? container.decodeIfPresent(Bool.self, forKey: .isComplete)) ?? true
	}
}
