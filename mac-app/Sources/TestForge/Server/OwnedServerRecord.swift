import Darwin
import Foundation

/// Remembers which server process this app started, so a relaunch can take it back instead of treating
/// it as someone else's (a server left running across a quit mid-test would otherwise never be stopped).
struct OwnedServerRecord: Codable, Equatable {
	let pid: Int32
	let port: String

	private enum CodingKeys: String, CodingKey {
		case pid
		case port
	}

	init(pid: Int32, port: String) {
		self.pid = pid
		self.port = port
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		pid = try container.decode(Int32.self, forKey: .pid)
		port = try container.decode(String.self, forKey: .port)
	}
}

protocol OwnedServerRecording {
	func save(record: OwnedServerRecord)
	func clear()

	/// The recorded server, only while that pid is still a live `node` process.
	func liveRecord(forPort port: String) -> OwnedServerRecord?
}

struct OwnedServerRecordStore: OwnedServerRecording {
	private let fileURL: URL
	private let fileManager: FileManager

	init(fileURL: URL, fileManager: FileManager = .default) {
		self.fileURL = fileURL
		self.fileManager = fileManager
	}

	func save(record: OwnedServerRecord) {
		guard let data = try? JSONEncoder().encode(record) else {
			return
		}
		try? data.write(to: fileURL, options: .atomic)
	}

	func clear() {
		try? fileManager.removeItem(at: fileURL)
	}

	func liveRecord(forPort port: String) -> OwnedServerRecord? {
		guard let data = try? Data(contentsOf: fileURL),
			let record = try? JSONDecoder().decode(OwnedServerRecord.self, from: data),
			record.port == port,
			isNodeProcess(pid: record.pid)
		else {
			return nil
		}
		return record
	}

	/// Guards against pid reuse: the pid must still exist and still be `node`.
	private func isNodeProcess(pid: Int32) -> Bool {
		guard kill(pid, 0) == 0 else {
			return false
		}
		var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
		let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
		guard pathLength > 0 else {
			return false
		}
		let executablePath = String(cString: pathBuffer)
		return (executablePath as NSString).lastPathComponent == "node"
	}
}
