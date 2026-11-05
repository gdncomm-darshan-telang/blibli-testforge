import SwiftUI

struct OnboardingRolePickerView: View {
	@Binding var selection: OnboardingRole

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.large) {
			ForEach(OnboardingRole.allCases) { role in
				Button {
					selection = role
				} label: {
					roleCard(role)
				}
				.buttonStyle(.plain)
				.accessibilityIdentifier(OnboardingConstants.Accessibility.rolePrefix + role.rawValue)
			}
		}
	}

	@ViewBuilder
	private func roleCard(_ role: OnboardingRole) -> some View {
		let isSelected = role == selection
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Image(systemName: role.symbolName)
				.font(.title)
				.foregroundStyle(Color.accentColor)
			Text(role.title)
				.font(.title3.bold())
			Text(role.subtitle)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(TestForgeConstants.Spacing.large)
		.frame(maxWidth: .infinity, minHeight: OnboardingConstants.Layout.roleCardHeight, alignment: .topLeading)
		.background(cardShape.fill(.quaternary.opacity(OnboardingConstants.Layout.surfaceOpacity)))
		.overlay(cardShape.stroke(borderColor(isSelected), lineWidth: borderWidth(isSelected)))
		.contentShape(cardShape)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}

	private var cardShape: RoundedRectangle {
		RoundedRectangle(cornerRadius: OnboardingConstants.Layout.cardCornerRadius)
	}

	private func borderColor(_ isSelected: Bool) -> Color {
		isSelected ? Color.accentColor : Color.secondary.opacity(OnboardingConstants.Layout.borderOpacity)
	}

	private func borderWidth(_ isSelected: Bool) -> CGFloat {
		isSelected ? OnboardingConstants.Layout.selectedBorderWidth : OnboardingConstants.Layout.borderWidth
	}
}
