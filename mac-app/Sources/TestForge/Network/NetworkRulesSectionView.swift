import SwiftUI

/// Rules tab body: rule list on the left, the selected rule's answers and body on the right; the editor opens as a sheet.
struct NetworkRulesSectionView<ViewModel: NetworkRulesPresenting>: View {
	@ObservedObject var viewModel: ViewModel

	var body: some View {
		HStack(spacing: 0) {
			ruleList
				.frame(width: NetworkConsoleConstants.Rules.listWidth)
			Divider()
			preview
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.sheet(item: $viewModel.editor) { editor in
			NetworkVariantEditorSheetView(viewModel: editor)
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.rules)
	}

	@ViewBuilder
	private var ruleList: some View {
		if let rules = viewModel.state.content {
			let indexedRules = Array(rules.enumerated())
			let actions = NetworkRuleRowActions(setEnabled: viewModel.setRule, activate: viewModel.activate)
			List(selection: $viewModel.selectedRuleId) {
				ForEach(indexedRules, id: \.element.id) { index, rule in
					let status = NetworkRuleRowStatus(index: index, isBusy: viewModel.busyRuleIds.contains(rule.id))
					NetworkRuleRowView(rule: rule, status: status, actions: actions)
						.tag(rule.id)
				}
			}
			.listStyle(.inset)
		} else if let phase = NetworkPlaceholderPhase(state: viewModel.state) {
			NetworkPlaceholderView(phase: phase)
		}
	}

	@ViewBuilder
	private var preview: some View {
		if let rule = viewModel.selectedRule {
			NetworkVariantPreviewView(rule: rule, edit: viewModel.edit)
		} else {
			NetworkPlaceholderView(phase: .empty(String(localized: "Pick a rule to see its answers")))
		}
	}
}
