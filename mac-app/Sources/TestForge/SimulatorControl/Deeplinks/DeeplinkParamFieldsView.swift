import SwiftUI

/// A route slot spelled out: what it fills in the link, and whether it can stay empty.
struct DeeplinkParamField: Identifiable, Equatable {
	let name: String
	let label: String
	let prompt: String
	let help: String

	var id: String {
		name
	}
}

/// One labelled field per `{slot}` in the picked route's template.
struct DeeplinkParamFieldsView: View {
	let fields: [DeeplinkParamField]
	let values: [String: String]
	let onChange: (String, String) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			ForEach(fields) { field in
				HStack(spacing: TestForgeConstants.Spacing.medium) {
					Text(field.label)
						.foregroundStyle(.secondary)
						.fixedSize()
					TextField(field.label, text: binding(for: field.name), prompt: Text(field.prompt))
						.textFieldStyle(.roundedBorder)
						.help(field.help)
						.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkParamFieldPrefix + field.name)
				}
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkParamFields)
	}

	private func binding(for name: String) -> Binding<String> {
		Binding {
			values[name] ?? ""
		} set: { value in
			onChange(name, value)
		}
	}
}
