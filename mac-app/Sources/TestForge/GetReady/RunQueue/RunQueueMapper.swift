import Foundation

/// Running first, then up next in queue order, then the latest finished; the server keeps up to 200 tasks.
enum RunQueueMapper {
	private static let recentFinishedLimit = 15
	private static let finishedStatuses: Set<String> = ["done", "failed", "cancelled"]

	static func content(for snapshot: RunQueueSnapshot?) -> RunQueueContent {
		let tasks = snapshot?.tasks ?? []
		let running = tasks.filter { $0.status == "running" }
		let queued = tasks.filter { $0.status == "queued" }
		let finished = Array(tasks.filter { finishedStatuses.contains($0.status) }.suffix(recentFinishedLimit).reversed())
		var groups: [RunQueueGroup] = []
		if !running.isEmpty {
			groups.append(RunQueueGroup(id: "running", title: String(localized: "Running"), rows: running.map { row(for: $0, queued: queued) }))
		}
		if !queued.isEmpty {
			groups.append(RunQueueGroup(id: "queued", title: String(localized: "Up next (\(queued.count))"), rows: queued.map { row(for: $0, queued: queued) }))
		}
		if !finished.isEmpty {
			groups.append(RunQueueGroup(id: "finished", title: String(localized: "Recent"), rows: finished.map { row(for: $0, queued: queued) }))
		}
		return RunQueueContent(deviceText: deviceText(for: snapshot), groups: groups, hasFinished: !finished.isEmpty)
	}

	private static func deviceText(for snapshot: RunQueueSnapshot?) -> String {
		guard let holder = snapshot?.deviceHolder else {
			return String(localized: "The simulator is free.")
		}
		let waitingCount = snapshot?.waitingCount ?? 0
		if waitingCount > 0 {
			return String(localized: "The simulator is held by “\(holder)” · \(waitingCount) waiting")
		}
		return String(localized: "The simulator is held by “\(holder)”")
	}

	private static func row(for task: RunQueueTask, queued: [RunQueueTask]) -> RunQueueRowModel {
		let queueIndex = queued.firstIndex { $0.id == task.id }
		let isFinished = finishedStatuses.contains(task.status)
		return RunQueueRowModel(
			id: task.id,
			title: task.title,
			detail: detail(for: task),
			statusSymbol: symbol(for: task),
			tone: tone(for: task),
			isRunning: task.status == "running",
			canMoveUp: queueIndex.map { $0 > 0 } ?? false,
			canMoveDown: queueIndex.map { $0 < queued.count - 1 } ?? false,
			canCancel: !isFinished,
			canRetry: isFinished
		)
	}

	private static func detail(for task: RunQueueTask) -> String {
		let lane = task.lane == "device" ? String(localized: "simulator") : String(localized: "parallel")
		var parts = [lane, task.status]
		if let startedAt = task.startedAt {
			let seconds = Int((task.endedAt ?? Date()).timeIntervalSince(startedAt))
			parts.append(Duration.seconds(seconds).formatted(.units(allowed: [.minutes, .seconds], width: .narrow)))
		}
		if let verdict = task.verdict {
			parts.append(verdict)
		}
		if let error = task.error {
			parts.append(error)
		}
		return parts.joined(separator: " · ")
	}

	private static func symbol(for task: RunQueueTask) -> String {
		switch task.status {
			case "queued":
				return "clock"
			case "done":
				return task.verdict == "FAIL" ? "xmark.circle.fill" : "checkmark.circle.fill"
			case "failed":
				return "exclamationmark.triangle.fill"
			case "cancelled":
				return "slash.circle"
			default:
				return "play.circle.fill"
		}
	}

	private static func tone(for task: RunQueueTask) -> VerdictTone {
		switch task.status {
			case "done":
				return task.verdict == "FAIL" ? .failed : .passed
			case "failed":
				return .failed
			case "queued", "cancelled":
				return .notRun
			default:
				return .neutral
		}
	}
}
