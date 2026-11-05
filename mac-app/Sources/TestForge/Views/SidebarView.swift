import SwiftUI

struct SidebarView: View {
	@Binding var selection: TestForgeSection

	/// Counts shown beside a section (Claude: approvals and questions waiting, D-147).
	let badges: [TestForgeSection: Int]

	var body: some View {
		List(TestForgeSection.allCases, selection: $selection) { section in
			SidebarRowView(section: section, isSelected: section == selection)
			.badge(badges[section] ?? 0)
			.tag(section)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.sidebarRowPrefix + section.rawValue)
		}
		.listStyle(.sidebar)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.sidebar)
	}
}
