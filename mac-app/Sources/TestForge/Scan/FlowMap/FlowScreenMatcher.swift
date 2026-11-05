import CoreGraphics
import Foundation

/// What one read of the device tree says about the screen: its fingerprint, a nav-bar-like title, a suggested name.
struct FlowScreenReading: Equatable {
	let fingerprint: Set<String>
	let title: String?
	let suggestedName: String?

	/// Visible identifiers as the app sets them; a new one after a tap is what replay waits for.
	var identifiers: Set<String> = []
}

/// Pure screen identity: turns a device tree into a fingerprint and decides whether it is a screen already on the map.
/// Identifiers are the signal; numbered siblings (`Banner_0…_11`) collapse to one token so data doesn't make a new screen.
enum FlowScreenMatcher {
	private static let numberedSuffix = try? NSRegularExpression(pattern: "([_.\\-]?\\d+)+$")
	private static let clockText = try? NSRegularExpression(pattern: "^\\d{1,2}:\\d{2}$")

	static func reading(elements: [SimulatorElement], screenFrame: CGRect) -> FlowScreenReading {
		let visible = elements.filter { $0.frame.width > 0 && $0.frame.height > 0 && $0.frame.intersects(screenFrame) }
		let fingerprint = Set(visible.compactMap { normalized(identifier: $0.identifier) })
		let title = navigationTitle(elements: visible, screenFrame: screenFrame)
		let suggestedName = title ?? dominantPrefix(fingerprint: fingerprint).map { "\($0) screen" }
		let identifiers = Set(visible.map(\.identifier).filter { !$0.isEmpty })
		return FlowScreenReading(fingerprint: fingerprint, title: title, suggestedName: suggestedName, identifiers: identifiers)
	}

	/// The identifier replay should wait for after a step: one that wasn't on the screen before, preferring a
	/// nav bar or title, and never a numbered row (`Banner_3`), which depends on the data.
	static func anchorIdentifier(before: FlowScreenReading?, after: FlowScreenReading) -> String? {
		let added = after.identifiers.subtracting(before?.identifiers ?? [])
		let stable = added.filter { normalized(identifier: $0) == $0 }
		let candidates = stable.isEmpty ? added : stable
		let preferred = candidates.filter { identifier in
			["navbar", "title", "header"].contains { identifier.lowercased().contains($0) }
		}
		return (preferred.isEmpty ? candidates : preferred).min()
	}

	/// The best screen already on the map for this reading, or nil when it is a new screen.
	static func match(reading: FlowScreenReading, screens: [FlowScreen]) -> FlowScreen? {
		let scored = screens.map { screen in
			(screen: screen, score: similarity(lhs: reading.fingerprint, rhs: screen.fingerprint))
		}
		let candidates = scored.filter { candidate in
			let hasSameTitle = reading.title != nil && reading.title == candidate.screen.title
			let threshold = hasSameTitle ? TestForgeConstants.FlowMap.sameTitleMatchThreshold : TestForgeConstants.FlowMap.matchThreshold
			return candidate.score >= threshold
		}
		return candidates.max { $0.score < $1.score }?.screen
	}

	/// Jaccard overlap; two screens without identifiers only match through their title.
	static func similarity(lhs: Set<String>, rhs: Set<String>) -> Double {
		let union = lhs.union(rhs)
		guard !union.isEmpty else {
			return 0
		}
		return Double(lhs.intersection(rhs).count) / Double(union.count)
	}

	static func normalized(identifier: String) -> String? {
		let trimmed = identifier.trimmingCharacters(in: .whitespaces)
		guard !trimmed.isEmpty else {
			return nil
		}
		let range = NSRange(trimmed.startIndex..., in: trimmed)
		let stripped = numberedSuffix?.stringByReplacingMatches(in: trimmed, range: range, withTemplate: "") ?? trimmed
		return stripped.isEmpty ? trimmed : stripped
	}

	/// Topmost text near the horizontal centre of the top band, skipping the status bar clock.
	private static func navigationTitle(elements: [SimulatorElement], screenFrame: CGRect) -> String? {
		let bandBottom = screenFrame.minY + screenFrame.height * TestForgeConstants.FlowMap.titleBandFraction
		let centreTolerance = screenFrame.width * TestForgeConstants.FlowMap.titleCentreFraction
		let candidates = elements.filter { element in
			// Long text or "Kirim ke: <address>" is content near the top, not a screen title.
			guard element.role == "AXStaticText" || element.role == "AXHeading",
				!element.label.isEmpty,
				element.label.count <= TestForgeConstants.FlowMap.titleMaximumLength,
				!element.label.contains(":"),
				element.frame.midY <= bandBottom,
				abs(element.frame.midX - screenFrame.midX) <= centreTolerance
			else {
				return false
			}
			let range = NSRange(element.label.startIndex..., in: element.label)
			return clockText?.firstMatch(in: element.label, range: range) == nil
		}
		return candidates.min { $0.frame.minY < $1.frame.minY }?.label
	}

	/// "Home" for `HomeSearchButton`, `HomeScanButton`…; "FS" for `FS_NavBar`, `FS_Tab`… when one prefix dominates.
	private static func dominantPrefix(fingerprint: Set<String>) -> String? {
		var counts: [String: Int] = [:]
		for identifier in fingerprint {
			guard let prefix = prefix(of: identifier) else {
				continue
			}
			counts[prefix, default: 0] += 1
		}
		guard let best = counts.max(by: { $0.value < $1.value }),
			best.value >= TestForgeConstants.FlowMap.minimumPrefixCount
		else {
			return nil
		}
		return best.key
	}

	private static func prefix(of identifier: String) -> String? {
		if let separator = identifier.firstIndex(where: { $0 == "_" || $0 == "." || $0 == "-" }) {
			let head = String(identifier[..<separator])
			return head.isEmpty ? nil : head
		}
		guard let first = identifier.first,
			first.isUppercase
		else {
			return nil
		}
		let rest = identifier.dropFirst()
		let wordEnd = rest.firstIndex { $0.isUppercase } ?? rest.endIndex
		return String(first) + String(rest[..<wordEnd])
	}
}
