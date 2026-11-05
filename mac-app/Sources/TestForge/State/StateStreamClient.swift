import Foundation

struct SliceSnapshot: Decodable, Equatable {
	let value: JSONValue
	let version: Int
	let error: String?

	private enum CodingKeys: String, CodingKey {
		case value
		case version
		case error
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		value = (try? container.decodeIfPresent(JSONValue.self, forKey: .value)) ?? .null
		version = (try? container.decodeIfPresent(Int.self, forKey: .version)) ?? 0
		error = try? container.decodeIfPresent(String.self, forKey: .error)
	}

	init(value: JSONValue, version: Int, error: String?) {
		self.value = value
		self.version = version
		self.error = error
	}
}

struct StateSnapshot: Decodable {
	let slices: [String: SliceSnapshot]

	private enum CodingKeys: String, CodingKey {
		case slices
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		slices = (try? container.decodeIfPresent([String: SliceSnapshot].self, forKey: .slices)) ?? [:]
	}
}

struct SlicePatch: Decodable {
	let slice: String
	let snapshot: SliceSnapshot

	private enum CodingKeys: String, CodingKey {
		case slice
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		slice = try container.decode(String.self, forKey: .slice)
		snapshot = try SliceSnapshot(from: decoder)
	}
}

enum StateStreamEvent {
	case snapshot(StateSnapshot)
	case patch(SlicePatch)
}

protocol StateStreaming {
	/// Ends when the server closes the connection; throws on a network failure.
	func events(from streamURL: URL) -> AsyncThrowingStream<StateStreamEvent, Error>
}

/// Reads the dashboard's `/api/state/stream` SSE feed (`snapshot`, then `patch` events).
struct StateStreamClient: StateStreaming {
	private let session: URLSession

	init(session: URLSession = .shared) {
		self.session = session
	}

	func events(from streamURL: URL) -> AsyncThrowingStream<StateStreamEvent, Error> {
		AsyncThrowingStream { continuation in
			let task = Task {
				do {
					try await readEvents(from: streamURL, into: continuation)
					continuation.finish()
				} catch {
					continuation.finish(throwing: error)
				}
			}
			continuation.onTermination = { _ in
				task.cancel()
			}
		}
	}

	/// Dispatches on each `data:` line: the server writes one `event:` line and one single-line `data:` per event,
	/// and `AsyncLineSequence` drops the blank separator lines SSE normally relies on.
	private func readEvents(from streamURL: URL, into continuation: AsyncThrowingStream<StateStreamEvent, Error>.Continuation) async throws {
		var request = URLRequest(url: streamURL)
		request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
		request.timeoutInterval = .infinity
		let (bytes, response) = try await session.bytes(for: request)
		guard let httpResponse = response as? HTTPURLResponse,
			httpResponse.statusCode == 200
		else {
			throw URLError(.badServerResponse)
		}
		var eventName = "message"
		for try await line in bytes.lines {
			if line.hasPrefix("event:") {
				eventName = line.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
			} else if line.hasPrefix("data:") {
				let payload = Data(line.dropFirst("data:".count).utf8)
				if let event = decodeEvent(named: eventName, payload: payload) {
					continuation.yield(event)
				}
				eventName = "message"
			}
		}
	}

	private func decodeEvent(named eventName: String, payload: Data) -> StateStreamEvent? {
		let decoder = JSONDecoder()
		switch eventName {
			case "snapshot":
				guard let snapshot = try? decoder.decode(StateSnapshot.self, from: payload) else {
					return nil
				}
				return .snapshot(snapshot)
			case "patch":
				guard let patch = try? decoder.decode(SlicePatch.self, from: payload) else {
					return nil
				}
				return .patch(patch)
			default:
				return nil
		}
	}
}
