import Foundation

struct SimulatorDevice: Equatable, Identifiable, Hashable {
	let id: String
	let name: String
	let runtime: String
	let isBooted: Bool
}

/// The value types `defaults write` accepts from the Simulator form.
enum UserDefaultValueType: String, CaseIterable, Identifiable {
	case string
	case bool
	case int
	case float

	var id: String { rawValue }

	var flag: String {
		"-\(rawValue)"
	}
}

struct UserDefaultEntry {
	let bundleId: String
	let key: String
	let type: UserDefaultValueType
	let value: String
}

protocol SimulatorControlling {
	func devices() async throws -> [SimulatorDevice]
	func boot(udid: String) async throws -> CommandOutput
	func shutdown(udid: String) async throws -> CommandOutput
	func showSimulatorApp() async throws -> CommandOutput
	func launch(udid: String, bundleId: String) async throws -> CommandOutput
	func terminate(udid: String, bundleId: String) async throws -> CommandOutput
	func readDefault(udid: String, bundleId: String, key: String) async throws -> CommandOutput
	func writeDefault(udid: String, entry: UserDefaultEntry) async throws -> CommandOutput
	func deleteDefault(udid: String, bundleId: String, key: String) async throws -> CommandOutput
	func resetPrivacy(udid: String, bundleId: String) async throws -> CommandOutput
	func resetKeychain(udid: String) async throws -> CommandOutput

	/// Wipes every app and setting on the device; it must be shut down first, so this shuts it down.
	func erase(udid: String) async throws -> CommandOutput

	func isBlendedLayersOn(udid: String) throws -> Bool
	func setBlendedLayers(udid: String, isOn: Bool) throws

	func screenshot(udid: String, path: String) async throws -> CommandOutput
}

/// Every action is a plain `xcrun simctl` call (shown in the console), except Color Blended Layers, which uses CoreSimulator.
struct SimulatorControlService: SimulatorControlling {
	private static let xcrun = "/usr/bin/xcrun"

	let runner: CommandRunning

	func devices() async throws -> [SimulatorDevice] {
		let output = try await simctl(["list", "devices", "available", "-j"])
		let list = try JSONDecoder().decode(SimctlDeviceList.self, from: Data(output.output.utf8))
		let devices = list.devices.flatMap { runtime, entries in
			entries.map { entry in
				SimulatorDevice(id: entry.udid, name: entry.name, runtime: Self.runtimeName(runtime), isBooted: entry.state == "Booted")
			}
		}
		return devices.sorted { ($0.isBooted ? 0 : 1, $0.runtime, $0.name) < ($1.isBooted ? 0 : 1, $1.runtime, $1.name) }
	}

	func boot(udid: String) async throws -> CommandOutput {
		try await simctl(["boot", udid])
	}

	func shutdown(udid: String) async throws -> CommandOutput {
		try await simctl(["shutdown", udid])
	}

	func showSimulatorApp() async throws -> CommandOutput {
		try await runner.run(CommandRequest(executable: "/usr/bin/open", arguments: ["-a", "Simulator"]))
	}

	func launch(udid: String, bundleId: String) async throws -> CommandOutput {
		try await simctl(["launch", "--terminate-running-process", udid, bundleId])
	}

	func terminate(udid: String, bundleId: String) async throws -> CommandOutput {
		try await simctl(["terminate", udid, bundleId])
	}

	func screenshot(udid: String, path: String) async throws -> CommandOutput {
		try await simctl(["io", udid, "screenshot", "--type=png", path])
	}

	func readDefault(udid: String, bundleId: String, key: String) async throws -> CommandOutput {
		let domain = try await appPreferencesDomain(udid: udid, bundleId: bundleId)
		return try await simctl(["spawn", udid, "defaults", "read", domain, key])
	}

	func writeDefault(udid: String, entry: UserDefaultEntry) async throws -> CommandOutput {
		let domain = try await appPreferencesDomain(udid: udid, bundleId: entry.bundleId)
		return try await simctl(["spawn", udid, "defaults", "write", domain, entry.key, entry.type.flag, entry.value])
	}

	func deleteDefault(udid: String, bundleId: String, key: String) async throws -> CommandOutput {
		let domain = try await appPreferencesDomain(udid: udid, bundleId: bundleId)
		return try await simctl(["spawn", udid, "defaults", "delete", domain, key])
	}

	/// The app's own plist by path; the bundle id alone is the simulator's shared domain, which the app never reads (D-127).
	private func appPreferencesDomain(udid: String, bundleId: String) async throws -> String {
		let container = try await simctl(["get_app_container", udid, bundleId, "data"])
		let path = container.output.trimmingCharacters(in: .whitespacesAndNewlines)
		guard container.isSuccess,
			!path.isEmpty else {
			return bundleId
		}
		return URL(fileURLWithPath: path).appendingPathComponent("Library/Preferences/\(bundleId)").path
	}

	func resetPrivacy(udid: String, bundleId: String) async throws -> CommandOutput {
		try await simctl(["privacy", udid, "reset", "all", bundleId])
	}

	func resetKeychain(udid: String) async throws -> CommandOutput {
		try await simctl(["keychain", udid, "reset"])
	}

	func erase(udid: String) async throws -> CommandOutput {
		_ = try await simctl(["shutdown", udid])
		return try await simctl(["erase", udid])
	}

	func isBlendedLayersOn(udid: String) throws -> Bool {
		try BlendedLayersSwitch(udid: udid).isOn
	}

	func setBlendedLayers(udid: String, isOn: Bool) throws {
		try BlendedLayersSwitch(udid: udid).set(isOn: isOn)
	}

	private func simctl(_ arguments: [String]) async throws -> CommandOutput {
		try await runner.run(CommandRequest(executable: Self.xcrun, arguments: ["simctl"] + arguments))
	}

	/// "com.apple.CoreSimulator.SimRuntime.iOS-18-0" → "iOS 18.0".
	private static func runtimeName(_ identifier: String) -> String {
		let last = identifier.split(separator: ".").last.map(String.init) ?? identifier
		let parts = last.split(separator: "-")
		guard let platform = parts.first else {
			return last
		}
		return "\(platform) " + parts.dropFirst().joined(separator: ".")
	}
}

private struct SimctlDeviceList: Decodable {
	let devices: [String: [SimctlDevice]]

	private enum CodingKeys: String, CodingKey {
		case devices
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		devices = (try? container.decodeIfPresent([String: [SimctlDevice]].self, forKey: .devices)) ?? [:]
	}
}

private struct SimctlDevice: Decodable {
	let udid: String
	let name: String
	let state: String

	private enum CodingKeys: String, CodingKey {
		case udid
		case name
		case state
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		udid = (try? container.decodeIfPresent(String.self, forKey: .udid)) ?? ""
		name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
		state = (try? container.decodeIfPresent(String.self, forKey: .state)) ?? ""
	}
}
