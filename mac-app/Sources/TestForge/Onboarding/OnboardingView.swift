import SwiftUI

/// The welcome tour sheet: step list on the left, the page on the right, Back / Next below.
struct OnboardingView<ViewModel: OnboardingPresenting>: View {
	@ObservedObject var viewModel: ViewModel

	var body: some View {
		HStack(spacing: 0) {
			OnboardingStepListView(current: viewModel.step, select: viewModel.show)
				.frame(width: OnboardingConstants.Layout.stepListWidth)
			Divider()
			VStack(spacing: 0) {
				ScrollView {
					page
						.padding(TestForgeConstants.Spacing.large)
						.frame(maxWidth: .infinity, alignment: .leading)
				}
				Divider()
				OnboardingFooterView(
					canGoBack: viewModel.canGoBack,
					isLastStep: viewModel.isLastStep,
					actions: footerActions
				)
			}
		}
		.frame(width: OnboardingConstants.Layout.width, height: OnboardingConstants.Layout.height)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(OnboardingConstants.Accessibility.sheet)
	}

	@ViewBuilder
	private var page: some View {
		let content = viewModel.content
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
			HStack(alignment: .firstTextBaseline) {
				Text(content.headline)
					.font(.title.bold())
				Spacer()
				if viewModel.step.isRoleSpecific {
					rolePicker
				}
			}
			Text(content.intro)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
			pageBody(content)
		}
	}

	@ViewBuilder
	private func pageBody(_ content: OnboardingPageContent) -> some View {
		switch viewModel.step {
			case .welcome:
				OnboardingRolePickerView(selection: $viewModel.role)
			case .start:
				OnboardingStartActionsView(perform: viewModel.perform)
			case .workflow:
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
					ForEach(content.flow) { flowStep in
						OnboardingFlowStepView(flowStep: flowStep)
					}
				}
			case .why, .howItWorks, .advantages, .safety:
				LazyVGrid(columns: gridColumns, alignment: .leading, spacing: TestForgeConstants.Spacing.medium) {
					ForEach(content.cards) { card in
						OnboardingCardView(card: card)
					}
				}
		}
	}

	private var rolePicker: some View {
		Picker("Tour for", selection: $viewModel.role) {
			ForEach(OnboardingRole.allCases) { role in
				Text(role.title).tag(role)
			}
		}
		.pickerStyle(.segmented)
		.fixedSize()
		.accessibilityIdentifier(OnboardingConstants.Accessibility.rolePicker)
	}

	private var gridColumns: [GridItem] {
		[GridItem(.adaptive(minimum: OnboardingConstants.Layout.cardMinWidth), spacing: TestForgeConstants.Spacing.medium)]
	}

	private var footerActions: OnboardingFooterActions {
		let viewModel = viewModel
		return OnboardingFooterActions(back: viewModel.goBack, next: viewModel.goForward, skip: viewModel.close)
	}
}
