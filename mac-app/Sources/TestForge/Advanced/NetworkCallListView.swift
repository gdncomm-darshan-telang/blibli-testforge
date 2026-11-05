import SwiftUI

/// The app's latest network calls as NetworkLens recorded them; selecting one loads its response body.
struct NetworkCallListView: View {
	let calls: [NetworkCallRowModel]
	@Binding var selection: String?
	let callBody: CallBodyState

	var body: some View {
		HStack(spacing: 0) {
			List(calls, selection: $selection) { call in
				NetworkCallRowView(call: call)
					.tag(call.id)
			}
			.frame(width: TestForgeConstants.Advanced.callListWidth)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.fakeDataCallList)
			.tutorialAnchor(.fakeDataCallList)
			Divider()
			bodyContent
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
				.accessibilityElement(children: .contain)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.fakeDataCallBody)
		}
	}

	@ViewBuilder
	private var bodyContent: some View {
		switch callBody {
			case .notSelected:
				EmptyStateView(content: EmptyStateContent(
					title: "Recent calls",
					systemImage: "network",
					message: "Select a call to see what the server answered."
				))
			case .loading:
				ProgressView()
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			case .loaded(let text):
				ScrollView {
					Text(text)
						.font(.caption.monospaced())
						.textSelection(.enabled)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(TestForgeConstants.Spacing.medium)
				}
			case .failed(let message):
				EmptyStateView(content: EmptyStateContent(
					title: "Couldn't load the body",
					systemImage: "exclamationmark.triangle",
					message: "\(message)"
				))
		}
	}
}
