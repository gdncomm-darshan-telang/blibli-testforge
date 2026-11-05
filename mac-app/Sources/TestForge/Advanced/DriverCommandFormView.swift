import SwiftUI

/// The command picker plus the fields that command takes; Send stays off until required fields are filled.
struct DriverCommandFormView: View {
	@ObservedObject var viewModel: PhoneRemoteViewModel

	var body: some View {
		Form {
			Section {
				Text(viewModel.hostText)
					.font(.callout)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.phoneRemoteHost)
				Picker("Command", selection: $viewModel.selectedKind) {
					ForEach(viewModel.commands) { command in
						Text(command.title).tag(command.kind)
					}
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.phoneRemoteKindPicker)
				.tutorialAnchor(.phoneRemoteKindPicker)
			}
			if let command = viewModel.selectedCommand,
				!command.fields.isEmpty {
				Section("Details") {
					ForEach(command.fields) { field in
						fieldControl(field: field)
					}
				}
			}
			Section {
				HStack {
					if case .sending(let title) = viewModel.sendState {
						ProgressView()
							.controlSize(.small)
						Text("Sending \(title)…")
							.foregroundStyle(.secondary)
					}
					Spacer()
					Button("Send") {
						viewModel.requestSend()
					}
					.keyboardShortcut(.defaultAction)
					.disabled(!viewModel.canSend)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.phoneRemoteSendButton)
					.tutorialAnchor(.phoneRemoteSendButton)
				}
			}
		}
		.formStyle(.grouped)
	}

	@ViewBuilder
	private func fieldControl(field: DriverCommandField) -> some View {
		let identifier = TestForgeConstants.Accessibility.phoneRemoteFieldPrefix + field.name
		switch field.kind {
			case .toggle:
				Toggle(field.prompt, isOn: toggleBinding(name: field.name))
					.accessibilityIdentifier(identifier)
			case .text, .number:
				TextField(field.isRequired ? field.prompt : "\(field.prompt) (optional)", text: textBinding(name: field.name))
					.accessibilityIdentifier(identifier)
		}
	}

	private func textBinding(name: String) -> Binding<String> {
		Binding {
			viewModel.textValues[name] ?? ""
		} set: { value in
			viewModel.textValues[name] = value
		}
	}

	private func toggleBinding(name: String) -> Binding<Bool> {
		Binding {
			viewModel.toggleValues[name] ?? false
		} set: { isOn in
			viewModel.toggleValues[name] = isOn
		}
	}
}
