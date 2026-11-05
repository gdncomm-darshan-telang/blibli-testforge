import Foundation

enum ScanSectionMapper {
	static func live(from scan: ScanState) -> ScanLiveModel {
		let title = scan.isStopping ? String(localized: "Stopping the scan…") : String(localized: "Scanning")
		let screenCount = scan.screens.count
		let deviceName = scan.deviceName ?? String(localized: "the simulator")
		let subtitle = String(localized: "Watching \(deviceName) · \(screenCount) screens marked · \(scan.skipped) skipped")
		let current = scan.current.map { currentModel(from: $0) }
		let screens = scan.screens.map { row(for: $0) }
		let warning = scan.pollError.map { String(localized: "Can't read the screen: \($0). Is the harness running?") } ?? scan.message
		return ScanLiveModel(title: title, subtitle: subtitle, current: current, screens: screens, warning: warning, isStopping: scan.isStopping)
	}

	/// Nil before any scan ran since the server started.
	static func summary(from scan: ScanState) -> ScanSummaryModel? {
		guard let endedAt = scan.endedAt else {
			return nil
		}
		let captureCount = scan.screens.reduce(0) { $0 + $1.variants.count }
		let endedText = endedAt.formatted(date: .omitted, time: .shortened)
		let detail = String(localized: "Ended \(endedText) · \(scan.screens.count) screens, \(captureCount) captures")
		let outURL = scan.outPath.map { URL(fileURLWithPath: $0) }
		let screens = scan.screens.map { row(for: $0) }
		return ScanSummaryModel(title: String(localized: "Last scan"), detail: detail, outURL: outURL, failure: scan.fatal, screens: screens)
	}

	private static func currentModel(from current: ScanCurrentScreen) -> ScanCurrentModel {
		let countsText = String(localized: "\(current.elementCount) elements · \(current.identifierCount) with identifiers · \(current.distinctSeen) screens seen")
		return ScanCurrentModel(countsText: countsText, identifiers: current.identifiers, isTruncated: current.isTruncated, changedAt: current.changedAt)
	}

	private static func row(for screen: ScanMarkedScreen) -> ScanScreenRowModel {
		let latest = screen.variants.last
		let incompleteCount = screen.variants.filter { !$0.isComplete }.count
		let mergedCount = screen.variants.reduce(0) { $0 + $1.merged }
		var parts = [String(localized: "\(screen.variants.count) captures")]
		if let latest {
			parts.append(String(localized: "\(latest.elementCount) elements"))
		}
		if incompleteCount > 0 {
			parts.append(String(localized: "\(incompleteCount) cut off — scroll and mark again"))
		}
		if mergedCount > 0 {
			parts.append(String(localized: "\(mergedCount) merged identifiers"))
		}
		let detail = parts.joined(separator: " · ")
		return ScanScreenRowModel(id: screen.name, name: screen.name, detail: detail, hasWarning: incompleteCount > 0 || mergedCount > 0)
	}
}
