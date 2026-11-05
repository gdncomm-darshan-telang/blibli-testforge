import SwiftUI

/// Tests detail (D-195): what the case's recording feeds the app — deeplinks it opens and the JSON it mocks.
struct CaseInputsPanelView: View {
	@ObservedObject var viewModel: CaseInputsViewModel
	let macroId: String?

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			HStack {
				Text("Deeplinks and mocks")
					.font(.headline)
				Spacer()
				if let message = viewModel.message {
					Text(message)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				if viewModel.canDownloadAll {
					Button("Download all…", action: viewModel.downloadAll)
						.accessibilityIdentifier(TestForgeConstants.Accessibility.testsInputsDownloadAll)
				}
			}
			content
		}
		.task(id: macroId) {
			viewModel.load(macroId: macroId)
		}
		.tutorialAnchor(.testsInputsPanel)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsInputsPanel)
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.state {
			case .noRecording:
				hint("No recording yet — the first Claude run records the deeplinks and mocks it uses.")
			case .loading:
				LoadingStateView(text: "Reading the recording…")
			case .empty:
				hint("The recording opens no deeplink and mocks nothing — it runs against the real server.")
			case .failed(let message):
				Label(message, systemImage: "exclamationmark.triangle")
					.foregroundStyle(.red)
					.textSelection(.enabled)
			case .loaded:
				loaded
		}
	}

	private var loaded: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			ForEach(viewModel.deeplinks, id: \.self) { link in
				HStack {
					Image(systemName: "link")
						.foregroundStyle(.secondary)
						.accessibilityHidden(true)
					Text(link)
						.font(.callout.monospaced())
						.textSelection(.enabled)
						.lineLimit(2)
					Spacer(minLength: 0)
					Button("Copy") {
						viewModel.copy(text: link)
					}
					.accessibilityIdentifier(TestForgeConstants.Accessibility.testsInputsCopyPrefix + link)
				}
				.accessibilityElement(children: .contain)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testsInputsDeeplinkPrefix + link)
			}
			ForEach(viewModel.mockRows) { row in
				let actions = CaseMockRowActions(copy: viewModel.copy(text:)) {
					viewModel.download(row: row)
				}
				CaseMockRowView(row: row, actions: actions)
			}
		}
	}

	private func hint(_ text: LocalizedStringKey) -> some View {
		Text(text)
			.font(.callout)
			.foregroundStyle(.secondary)
			.fixedSize(horizontal: false, vertical: true)
	}
}
