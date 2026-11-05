import CoreGraphics
import Foundation

struct DeviceScreen: Decodable, Equatable {
	let deviceName: String?
	let udid: String?
	let size: CGSize

	private enum CodingKeys: String, CodingKey {
		case deviceName
		case udid
		case width
		case height
	}

	init(deviceName: String?, size: CGSize, udid: String? = nil) {
		self.deviceName = deviceName
		self.size = size
		self.udid = udid
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		deviceName = try? container.decodeIfPresent(String.self, forKey: .deviceName)
		udid = try? container.decodeIfPresent(String.self, forKey: .udid)
		let width = (try? container.decodeIfPresent(Double.self, forKey: .width)) ?? 0
		let height = (try? container.decodeIfPresent(Double.self, forKey: .height)) ?? 0
		size = CGSize(width: width, height: height)
	}
}

protocol DeviceScreenReading: Sendable {
	func screen() async throws -> DeviceScreen
	func screenshot() async throws -> Data

	/// Keeps the server reading a frame per replay step; it lapses after 90 s unless renewed.
	func leaseStepFrames(isOn: Bool) async throws
}

struct DeviceScreenService: DeviceScreenReading {
	private let client: DashboardClient

	init(client: DashboardClient) {
		self.client = client
	}

	func screen() async throws -> DeviceScreen {
		let data = try await client.get(path: "api/device/screen")
		return try JSONDecoder().decode(DeviceScreen.self, from: data)
	}

	func screenshot() async throws -> Data {
		try await client.get(path: "api/device/screenshot.jpg")
	}

	func leaseStepFrames(isOn: Bool) async throws {
		let body = ["on": isOn ? "true" : ""]
		try await client.post(path: "api/overlay", body: body)
	}
}
