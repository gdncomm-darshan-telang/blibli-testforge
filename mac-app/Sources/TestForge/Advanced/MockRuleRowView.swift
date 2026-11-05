import SwiftUI

struct MockRuleActions {
	let setEnabled: (_ ruleId: String, _ isEnabled: Bool) -> Void
	let activate: (_ ruleId: String, _ variantId: String) -> Void
}

/// One NetworkLens rule: on/off, the endpoint, and which canned answer it gives.
struct MockRuleRowView: View {
	let rule: MockRuleRowModel
	let isBusy: Bool
	let actions: MockRuleActions

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Toggle("Use this rule", isOn: enabledBinding)
				.labelsHidden()
				.toggleStyle(.checkbox)
				.disabled(isBusy)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.fakeDataRuleTogglePrefix + rule.id)
			Text(rule.method)
				.font(.caption.monospaced().bold())
				.foregroundStyle(.secondary)
				.frame(width: TestForgeConstants.Advanced.methodWidth, alignment: .leading)
			Text(rule.path)
				.font(.callout.monospaced())
				.lineLimit(1)
				.truncationMode(.head)
				.help(rule.path)
				.frame(maxWidth: .infinity, alignment: .leading)
			if isBusy {
				ProgressView()
					.controlSize(.small)
			}
			Picker("Answer", selection: variantBinding) {
				ForEach(rule.variants) { variant in
					Text(variant.name).tag(variant.id)
				}
			}
			.labelsHidden()
			.disabled(isBusy)
			.frame(width: TestForgeConstants.Advanced.variantPickerWidth, alignment: .trailing)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.fakeDataVariantPickerPrefix + rule.id)
		}
		.frame(maxWidth: .infinity)
		.opacity(rule.isEnabled ? 1 : TestForgeConstants.Advanced.disabledRuleOpacity)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.fakeDataRulePrefix + rule.id)
	}

	private var enabledBinding: Binding<Bool> {
		Binding {
			rule.isEnabled
		} set: { isEnabled in
			actions.setEnabled(rule.id, isEnabled)
		}
	}

	private var variantBinding: Binding<String> {
		Binding {
			rule.activeVariantId
		} set: { variantId in
			actions.activate(rule.id, variantId)
		}
	}
}
