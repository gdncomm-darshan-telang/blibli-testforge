import SwiftUI

struct DeeplinkQueryRowContent: Identifiable, Equatable {
	let item: DeeplinkQueryItem
	let valueChoices: [DeeplinkQueryValueChoice]

	var id: UUID {
		item.id
	}
}

/// One name = value row; known keys come from a menu, and a version key offers its versions the same way.
struct DeeplinkQueryRowView: View {
	let content: DeeplinkQueryRowContent
	let keyChoices: [DeeplinkQueryKeyChoice]
	let actions: DeeplinkQueryActions

	private var item: DeeplinkQueryItem {
		content.item
	}

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			TextField("Name", text: nameBinding, prompt: Text("name, e.g. utm_source"))
				.textFieldStyle(.roundedBorder)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkQueryNamePrefix + item.id.uuidString)
			keyMenu
			Text(verbatim: "=")
				.foregroundStyle(.secondary)
			TextField("Value", text: valueBinding, prompt: Text(content.valueChoices.isEmpty ? "value" : "version"))
				.textFieldStyle(.roundedBorder)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkQueryValuePrefix + item.id.uuidString)
			if !content.valueChoices.isEmpty {
				valueMenu
			}
			Button {
				actions.remove(item.id)
			} label: {
				Image(systemName: "minus.circle")
			}
			.buttonStyle(.borderless)
			.help("Remove this parameter")
			.accessibilityLabel("Remove parameter")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkQueryRemovePrefix + item.id.uuidString)
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkQueryRowPrefix + item.id.uuidString)
	}

	private var keyMenu: some View {
		Menu {
			ForEach(keyChoices) { choice in
				Button(choice.title) {
					actions.change(DeeplinkQueryItem(id: item.id, name: choice.key, value: item.value))
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkQueryKeyChoicePrefix + choice.key)
			}
		} label: {
			Image(systemName: "list.bullet")
		}
		.menuIndicator(.hidden)
		.fixedSize()
		.help("Pick a known parameter")
		.accessibilityLabel("Known parameters")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkQueryKeyMenuPrefix + item.id.uuidString)
	}

	private var valueMenu: some View {
		Menu {
			ForEach(content.valueChoices) { choice in
				Button(choice.title) {
					actions.change(DeeplinkQueryItem(id: item.id, name: item.name, value: choice.value))
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkQueryVersionChoicePrefix + choice.value)
			}
		} label: {
			Image(systemName: "number")
		}
		.menuIndicator(.hidden)
		.fixedSize()
		.help("Pick a version")
		.accessibilityLabel("Versions")
		.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkQueryVersionMenuPrefix + item.id.uuidString)
	}

	private var nameBinding: Binding<String> {
		Binding {
			item.name
		} set: { name in
			actions.change(DeeplinkQueryItem(id: item.id, name: name, value: item.value))
		}
	}

	private var valueBinding: Binding<String> {
		Binding {
			item.value
		} set: { value in
			actions.change(DeeplinkQueryItem(id: item.id, name: item.name, value: value))
		}
	}
}
