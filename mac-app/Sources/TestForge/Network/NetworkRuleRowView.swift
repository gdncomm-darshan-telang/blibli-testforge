import SwiftUI

struct NetworkRuleRowStatus {
	let index: Int
	let isBusy: Bool
}

struct NetworkRuleRowActions {
	let setEnabled: (_ ruleId: String, _ isEnabled: Bool) -> Void
	let activate: (_ ruleId: String, _ variantId: String) -> Void
}

/// One rule: on/off, endpoint, and which answer it gives — picking an answer also turns the rule on.
struct NetworkRuleRowView: View {
	let rule: NetworkRuleRowModel
	let status: NetworkRuleRowStatus
	let actions: NetworkRuleRowActions

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Toggle("Use this rule", isOn: enabledBinding)
				.labelsHidden()
				.toggleStyle(.checkbox)
				.disabled(status.isBusy)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.ruleTogglePrefix + String(status.index))
			Text(rule.method)
				.font(.caption.monospaced().bold())
				.foregroundStyle(.secondary)
				.frame(width: NetworkConsoleConstants.Traffic.methodWidth, alignment: .leading)
			Text(rule.path)
				.font(.callout.monospaced())
				.lineLimit(1)
				.truncationMode(.head)
				.help(rule.endpoint)
				.frame(maxWidth: .infinity, alignment: .leading)
			if status.isBusy {
				ProgressView()
					.controlSize(.small)
			}
			Picker("Answer", selection: variantBinding) {
				ForEach(rule.variants) { variant in
					Text(variant.name).tag(variant.id)
				}
			}
			.labelsHidden()
			.disabled(status.isBusy)
			.frame(width: NetworkConsoleConstants.Rules.variantPickerWidth)
			.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.variantPickerPrefix + String(status.index))
		}
		.opacity(rule.isEnabled ? 1 : NetworkConsoleConstants.Rules.disabledRuleOpacity)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.ruleRowPrefix + String(status.index))
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
