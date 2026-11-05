import SwiftUI

/// Adds a login or replaces one with the same environment and profile.
struct LoginFormView: View {
	@ObservedObject var viewModel: LoginsViewModel

	var body: some View {
		Picker("Environment", selection: $viewModel.draft.environment) {
			ForEach(viewModel.environments, id: \.self) { environment in
				Text(environment)
					.tag(environment)
			}
		}
		.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsEnvironment)
		TextField("Profile", text: $viewModel.draft.profile, prompt: Text("internal"))
			.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsProfile)
		TextField("Email", text: $viewModel.draft.email)
			.textContentType(.username)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsEmail)
		SecureField("Password", text: $viewModel.draft.password)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsPassword)
		SecureField("Static OTP", text: $viewModel.draft.otp, prompt: Text(viewModel.canStoreOtp ? "UAT B only" : "Asked at run time"))
			.disabled(!viewModel.canStoreOtp)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsOtp)
		HStack {
			Spacer()
			Button(viewModel.isSaving ? "Saving…" : "Save to Keychain") {
				viewModel.save()
			}
			.disabled(!viewModel.canSave)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.loginsSave)
		}
	}
}
