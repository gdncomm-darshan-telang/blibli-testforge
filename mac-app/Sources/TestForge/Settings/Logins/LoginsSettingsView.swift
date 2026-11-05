import SwiftUI

/// Settings › Logins (D-199): test accounts kept in the macOS Keychain; macros name them as environment/profile.
struct LoginsSettingsView: View {
	@ObservedObject var viewModel: LoginsViewModel

	var body: some View {
		Form {
			Section {
				savedLogins
			} header: {
				Text("Test logins")
			} footer: {
				Text("Kept in your macOS Keychain. Runs refer to them as environment/profile; passwords never appear in logs.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			Section("Add or update a login") {
				LoginFormView(viewModel: viewModel)
			}
			Section("Production OTP") {
				MailOtpRowView(
					status: viewModel.mailOtp,
					progress: viewModel.mailProgress,
					actions: MailOtpActions(link: viewModel.linkMailOtp, unlink: viewModel.unlinkMailOtp, copyCode: viewModel.copyMailCode)
				)
			}
			if let message = viewModel.message {
				Text(message)
					.font(.caption)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsMessage)
			}
		}
		.formStyle(.grouped)
		.task {
			viewModel.load()
		}
		.confirmationDialog(removalTitle, isPresented: isRemovalPresented, presenting: viewModel.pendingRemoval) { _ in
			Button("Remove", role: .destructive) {
				viewModel.confirmRemoval()
			}
			Button("Cancel", role: .cancel) {
				viewModel.pendingRemoval = nil
			}
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsSettings)
	}

	@ViewBuilder
	private var savedLogins: some View {
		switch viewModel.state {
			case .loading:
				LoadingStateView(text: "Reading the Keychain…")
			case .failed(let message):
				Text("Couldn't load logins: \(message)")
					.foregroundStyle(.secondary)
			case .loaded(let logins):
				if logins.isEmpty {
					Text("No logins yet.")
						.foregroundStyle(.secondary)
				}
				ForEach(logins) { login in
					LoginRowView(login: login, removalState: viewModel.removalState(for: login)) {
						viewModel.pendingRemoval = login
					}
				}
		}
	}

	private var removalTitle: Text {
		Text("Remove \(viewModel.pendingRemoval?.id ?? "") from the Keychain?")
	}

	private var isRemovalPresented: Binding<Bool> {
		Binding {
			viewModel.pendingRemoval != nil
		} set: { isPresented in
			if !isPresented {
				viewModel.pendingRemoval = nil
			}
		}
	}
}
