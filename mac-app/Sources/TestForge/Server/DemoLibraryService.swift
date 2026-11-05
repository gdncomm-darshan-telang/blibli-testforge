import Foundation

protocol DemoLibraryListing {
	func recordings() async throws -> [DemoRecording]
}

struct DemoLibraryService: DemoLibraryListing {
	private let client: DashboardClient

	init(client: DashboardClient) {
		self.client = client
	}

	func recordings() async throws -> [DemoRecording] {
		let data = try await client.get(path: "api/demo/recordings")
		return try JSONDecoder().decode(DemoRecordingList.self, from: data).recordings
	}
}
