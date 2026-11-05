import Foundation

/// `GET /api/devices/physical` (D-197): iPhones and iPads paired with this Mac.
struct PhysicalDeviceList: Decodable, Equatable {
	let devices: [PhysicalDevice]
	let error: String?

	private enum CodingKeys: String, CodingKey {
		case devices
		case error
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		devices = (try? container.decodeIfPresent([PhysicalDevice].self, forKey: .devices)) ?? []
		error = try? container.decodeIfPresent(String.self, forKey: .error)
	}
}

struct PhysicalDevice: Decodable, Equatable, Identifiable {
	let id: String
	let name: String
	let model: String?
	let osVersion: String?
	let connection: String?
	let isConnected: Bool
	let isDeveloperModeOn: Bool

	/// False until a device-signed QA build and runner exist; `blockers` says what is missing.
	let canRunTests: Bool

	let blockers: [String]

	private enum CodingKeys: String, CodingKey {
		case id
		case name
		case model
		case osVersion
		case connection
		case isConnected
		case isDeveloperModeOn
		case canRunTests
		case blockers
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
		name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? "iPhone"
		model = try? container.decodeIfPresent(String.self, forKey: .model)
		osVersion = try? container.decodeIfPresent(String.self, forKey: .osVersion)
		connection = try? container.decodeIfPresent(String.self, forKey: .connection)
		isConnected = (try? container.decodeIfPresent(Bool.self, forKey: .isConnected)) ?? false
		isDeveloperModeOn = (try? container.decodeIfPresent(Bool.self, forKey: .isDeveloperModeOn)) ?? false
		canRunTests = (try? container.decodeIfPresent(Bool.self, forKey: .canRunTests)) ?? false
		blockers = (try? container.decodeIfPresent([String].self, forKey: .blockers)) ?? []
	}
}

enum PhysicalDevicesState: Equatable {
	case loading
	case loaded
	case failed(message: String)
}

/// A device as its row shows it.
struct PhysicalDeviceRowModel: Equatable, Identifiable {
	let id: String
	let name: String
	let detailText: String
	let stateText: String
	let isConnected: Bool
}
