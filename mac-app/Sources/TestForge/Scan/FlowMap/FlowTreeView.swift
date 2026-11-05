import SwiftUI

struct FlowTreeView: View {
	let nodes: [FlowTreeNode]
	let currentScreenId: String?
	@Binding var selection: String?

	var body: some View {
		List(selection: $selection) {
			OutlineGroup(nodes, children: \.children) { node in
				FlowTreeRowView(node: node, isCurrent: !node.isLink && node.screenId == currentScreenId)
					.tag(node.screenId)
			}
		}
		.listStyle(.sidebar)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.flowMapTree)
	}
}
