import SwiftUI

struct NetworkCallDetailActions {
	let mockCall: () -> Void
	let copyCurl: () -> Void
	let replay: () -> Void
	let hold: () -> Void
}

/// One captured call: response first (what the screen got), then request, headers and the curl to hand a backend developer.
struct NetworkCallDetailView: View {
	let detail: TrafficCallDetailModel
	let actions: NetworkCallDetailActions
	let activity: NetworkCallActivity

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			header
			if let message = activity.resultMessage {
				Label(message, systemImage: activity.isResultSuccess ? "checkmark.circle" : "exclamationmark.triangle")
					.font(.caption)
					.foregroundStyle(activity.isResultSuccess ? Color.secondary : Color.red)
					.textSelection(.enabled)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.networkCallActionResult)
			}
			TabView {
				bodyText(detail.responseBody)
					.tabItem { Text("Response") }
				bodyText(detail.requestBody)
					.tabItem { Text("Request") }
				bodyText(headersText)
					.tabItem { Text("Headers") }
				bodyText(detail.curl)
					.tabItem { Text("curl") }
			}
		}
		.padding(TestForgeConstants.Spacing.medium)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.callDetail)
	}

	@ViewBuilder
	private var header: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Text(detail.statusText)
				.font(.headline.monospaced())
			NetworkMockedBadgeView(isMocked: detail.isMocked)
			Text(detail.title)
				.font(.callout.monospaced())
				.lineLimit(2)
				.truncationMode(.middle)
				.textSelection(.enabled)
				.frame(maxWidth: .infinity, alignment: .leading)
			Button("Copy curl", systemImage: "doc.on.doc", action: actions.copyCurl)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.copyCurlButton)
			Button(action: actions.replay) {
				ActionProgressLabel(
					title: String(localized: "Replay"),
					busyTitle: String(localized: "Replaying…"),
					isBusy: activity.runningAction == .replay
				)
			}
			.disabled(activity.runningAction != nil)
			.help("Send this request again from the app — mocks apply; the screen doesn't see the answer")
			.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.replayCallButton)
			Button("Hold this call", systemImage: "pause.circle", action: actions.hold)
				.help("Add a breakpoint on this endpoint: its next response waits for you under Breakpoints")
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.holdCallButton)
			Button(action: actions.mockCall) {
				ActionProgressLabel(
					title: String(localized: "Mock this call"),
					busyTitle: String(localized: "Making rule…"),
					isBusy: activity.runningAction == .mock
				)
			}
			.disabled(activity.runningAction != nil)
			.help("Its real response becomes a rule with loaded, empty, 500, slow and timeout answers")
			.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.mockCallButton)
		}
	}

	private var headersText: String {
		String(localized: "Request\n\(detail.requestHeaders)\n\nResponse\n\(detail.responseHeaders)")
	}

	private func bodyText(_ text: String) -> some View {
		ScrollView([.vertical, .horizontal]) {
			Text(text)
				.font(.callout.monospaced())
				.textSelection(.enabled)
				.frame(maxWidth: .infinity, alignment: .topLeading)
				.padding(TestForgeConstants.Spacing.small)
		}
	}
}
