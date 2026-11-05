import SwiftUI

/// Shown only while mocks are on: what is armed, what the repo pack doesn't know, and the ways back to real data.
struct NetworkGuardrailsBannerView<ViewModel: NetworkGuardrailsPresenting>: View {
	@ObservedObject var viewModel: ViewModel

	var body: some View {
		if let model = viewModel.state.content {
			HStack(alignment: .top, spacing: TestForgeConstants.Spacing.medium) {
				Image(systemName: "exclamationmark.shield")
					.foregroundStyle(.orange)
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
					Text(model.headline)
						.font(.callout.bold())
					ForEach(model.lines, id: \.self) { line in
						Text(line)
							.font(.caption)
							.foregroundStyle(.secondary)
							.textSelection(.enabled)
					}
					if let failure = viewModel.resetFailure {
						Label(failure, systemImage: "exclamationmark.triangle")
							.font(.caption)
							.foregroundStyle(.red)
							.textSelection(.enabled)
							.accessibilityIdentifier(TestForgeConstants.Accessibility.networkResetFailure)
					}
				}
				Spacer()
				if model.canResetToPack {
					Button {
						viewModel.requestReset(target: .pack)
					} label: {
						ActionProgressLabel(
							title: String(localized: "Reset to repo pack"),
							busyTitle: String(localized: "Resetting…"),
							isBusy: viewModel.runningReset == .pack
						)
					}
					.disabled(viewModel.runningReset != nil)
					.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.resetToPackButton)
				}
				Button {
					viewModel.requestReset(target: .allOff)
				} label: {
					ActionProgressLabel(
						title: String(localized: "All off"),
						busyTitle: String(localized: "Turning off…"),
						isBusy: viewModel.runningReset == .allOff
					)
				}
				.disabled(viewModel.runningReset != nil)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.allOffButton)
			}
			.padding(TestForgeConstants.Spacing.medium)
			.background(.orange.opacity(NetworkConsoleConstants.Surface.warningOpacity))
			.confirmationDialog(confirmTitle, isPresented: isConfirmShown) {
				Button(confirmButtonTitle, role: .destructive) {
					viewModel.confirmReset()
				}
			} message: {
				Text(confirmMessage)
			}
			.accessibilityElement(children: .contain)
			.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.guardrailsBanner)
		}
	}

	private var isConfirmShown: Binding<Bool> {
		Binding {
			viewModel.pendingReset != nil
		} set: { isShown in
			if !isShown {
				viewModel.pendingReset = nil
			}
		}
	}

	private var confirmTitle: String {
		viewModel.pendingReset == .pack ? String(localized: "Reset rules to the repo's pack?") : String(localized: "Turn every rule off?")
	}

	private var confirmButtonTitle: String {
		viewModel.pendingReset == .pack ? String(localized: "Reset") : String(localized: "All off")
	}

	private var confirmMessage: String {
		viewModel.pendingReset == .pack
			? String(localized: "Rules the pack keeps get the pack's answers back, switched off. Edited answers on them are replaced.")
			: String(localized: "The app goes back to the real backend. Rules and their answers stay, just off.")
	}
}
