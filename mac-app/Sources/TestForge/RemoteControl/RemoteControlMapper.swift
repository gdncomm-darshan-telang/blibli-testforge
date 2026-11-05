import Foundation

enum RemoteControlMapper {
	static func display(from state: RemoteControlState?) -> RemoteControlDisplay {
		guard let state,
			state.isRunning
		else {
			return RemoteControlDisplay(
				status: .off,
				title: String(localized: "Remote Control is off"),
				detail: String(localized: "Turn it on to run QA on this Mac from the Claude app (Code tab) or claude.ai/code."),
				openURL: nil,
				problem: nil,
				output: state?.output ?? []
			)
		}
		let openURL = state.sessionURLs.last ?? state.environmentURL
		let capacity = state.capacityUsed.map { used in
			String(localized: "\(used)/\(state.capacityMax ?? used) sessions")
		} ?? ""
		let mode = RemoteControlSpawnMode(rawValue: state.spawnMode)?.title ?? state.spawnMode
		switch state.phase {
			case "connected":
				return RemoteControlDisplay(
					status: .connected,
					title: String(localized: "Connected — “\(state.name)”"),
					detail: [capacity, mode].filter { !$0.isEmpty }.joined(separator: " · "),
					openURL: openURL,
					problem: nil,
					output: state.output
				)
			default:
				let status: RemoteControlDisplay.Status = state.problem == nil ? .starting : .problem
				return RemoteControlDisplay(
					status: status,
					title: String(localized: "Connecting…"),
					detail: mode,
					openURL: openURL,
					problem: state.problem,
					output: state.output
				)
		}
	}
}
