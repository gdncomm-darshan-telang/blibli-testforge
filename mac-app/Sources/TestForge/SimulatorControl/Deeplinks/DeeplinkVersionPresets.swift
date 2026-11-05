import Foundation

/// Min-version query keys spelled exactly as the app's own link does (`BlibliBonusManager`); the web page reads them, not the app.
enum DeeplinkVersionKey: String, CaseIterable {
	case android = "androidMinVersion"
	case ios = "iosminversion"

	var title: String {
		switch self {
			case .android:
				return String(localized: "Android min version · androidMinVersion")
			case .ios:
				return String(localized: "iOS min version · iosminversion")
		}
	}

	/// The app's iOS example drops the dots (`iosminversion=1140` for 11.4.0); Android keeps them (`11.0.0`).
	func value(for version: String) -> String {
		self == .ios ? version.replacingOccurrences(of: ".", with: "") : version
	}

	/// Case-insensitive, so a key typed as `iOSMinVersion` still gets the version list.
	static func matching(_ name: String) -> DeeplinkVersionKey? {
		let lowered = name.trimmingCharacters(in: .whitespaces).lowercased()
		return allCases.first { $0.rawValue.lowercased() == lowered }
	}
}

struct DeeplinkQueryKeyChoice: Identifiable, Equatable {
	let title: String
	let key: String

	var id: String {
		key
	}
}

struct DeeplinkQueryValueChoice: Identifiable, Equatable {
	let title: String
	let value: String

	var id: String {
		value
	}
}

/// Versions around the installed build, newest first, so a min version above, at and below it is one pick away.
enum DeeplinkVersionPresets {
	private static let fallbackVersion = "15.0.0"
	private static let olderMajorCount = 4

	static func values(for key: DeeplinkVersionKey, appVersion: String?) -> [DeeplinkQueryValueChoice] {
		let current = appVersion.flatMap(parse) ?? parse(fallbackVersion) ?? (15, 0, 0)
		let currentText = "\(current.major).\(current.minor).\(current.patch)"
		var versions: [(String, String?)] = [
			("\(current.major + 1).0.0", String(localized: "newer than this build")),
			("\(current.major).\(current.minor + 1).0", String(localized: "newer than this build")),
			(currentText, appVersion == nil ? nil : String(localized: "this build")),
		]
		if current.minor > 0 {
			versions.append(("\(current.major).\(current.minor - 1).0", String(localized: "older than this build")))
		}
		for step in 1...olderMajorCount where current.major - step > 0 {
			versions.append(("\(current.major - step).0.0", String(localized: "older than this build")))
		}
		return versions.map { version, note in
			let value = key.value(for: version)
			let title = [value == version ? version : "\(value) (\(version))", note].compactMap { $0 }.joined(separator: " — ")
			return DeeplinkQueryValueChoice(title: title, value: value)
		}
	}

	private static func parse(_ text: String) -> (major: Int, minor: Int, patch: Int)? {
		let parts = text.split(separator: ".").map { Int($0) }
		guard let major = parts.first ?? nil else {
			return nil
		}
		let minor = (parts.count > 1 ? parts[1] : 0) ?? 0
		let patch = (parts.count > 2 ? parts[2] : 0) ?? 0
		return (major, minor, patch)
	}
}
