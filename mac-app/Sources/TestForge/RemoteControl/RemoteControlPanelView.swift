import SwiftUI

struct RemoteControlPanelView<ViewModel: RemoteControlPresenting>: View {
	@ObservedObject var viewModel: ViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
			Text(viewModel.display.title)
				.font(.headline)
			Text(viewModel.display.detail)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
			if let problem = viewModel.display.problem {
				Label(problem, systemImage: "exclamationmark.triangle")
					.foregroundStyle(.red)
					.fixedSize(horizontal: false, vertical: true)
			}
			if viewModel.display.openURL != nil {
				linkSection
			}
			Divider()
			controls
			if let errorMessage = viewModel.errorMessage {
				Label(errorMessage, systemImage: "exclamationmark.triangle")
					.foregroundStyle(.red)
					.textSelection(.enabled)
					.fixedSize(horizontal: false, vertical: true)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.remoteControlFailure)
			}
			Text(RemoteControlConstants.Copy.footnote)
				.font(.caption)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(TestForgeConstants.Spacing.large)
		.frame(width: RemoteControlConstants.Layout.panelWidth)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(RemoteControlConstants.Accessibility.panel)
	}

	@ViewBuilder
	private var linkSection: some View {
		HStack(alignment: .top, spacing: TestForgeConstants.Spacing.medium) {
			if let qrImage = viewModel.qrImage {
				Image(nsImage: qrImage)
					.interpolation(.none)
					.resizable()
					.frame(width: RemoteControlConstants.Layout.qrSide, height: RemoteControlConstants.Layout.qrSide)
					.accessibilityLabel(Text("QR code for the session"))
					.accessibilityIdentifier(RemoteControlConstants.Accessibility.qrCode)
			}
			VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
				Text("Scan with your phone's camera, or open the Claude app › Code and pick this session.")
					.font(.callout)
					.fixedSize(horizontal: false, vertical: true)
				Button("Open session", systemImage: "safari", action: viewModel.openSession)
					.accessibilityIdentifier(RemoteControlConstants.Accessibility.openButton)
				Button("Copy link", systemImage: "link", action: viewModel.copyLink)
					.accessibilityIdentifier(RemoteControlConstants.Accessibility.copyButton)
			}
		}
	}

	@ViewBuilder
	private var controls: some View {
		HStack {
			Picker("New sessions", selection: $viewModel.spawnMode) {
				ForEach(RemoteControlSpawnMode.allCases) { mode in
					Text(mode.title).tag(mode)
				}
			}
			.disabled(viewModel.display.status != .off)
			.fixedSize()
			.accessibilityIdentifier(RemoteControlConstants.Accessibility.spawnModePicker)
			Spacer()
			if viewModel.display.status == .off {
				Button(action: viewModel.start) {
					ActionProgressLabel(title: String(localized: "Turn on"), busyTitle: String(localized: "Turning on…"), isBusy: viewModel.isWorking)
				}
				.keyboardShortcut(.defaultAction)
				.disabled(viewModel.isWorking)
				.accessibilityIdentifier(RemoteControlConstants.Accessibility.startButton)
			} else {
				Button(role: .destructive, action: viewModel.stop) {
					ActionProgressLabel(title: String(localized: "Turn off"), busyTitle: String(localized: "Turning off…"), isBusy: viewModel.isWorking)
				}
				.disabled(viewModel.isWorking)
				.accessibilityIdentifier(RemoteControlConstants.Accessibility.stopButton)
			}
		}
	}
}
