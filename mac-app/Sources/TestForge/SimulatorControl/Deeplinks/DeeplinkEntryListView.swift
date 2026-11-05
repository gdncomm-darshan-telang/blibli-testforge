import SwiftUI

struct DeeplinkEntryGroups {
	let saved: [DeeplinkEntryRow]
	let recent: [DeeplinkEntryRow]
}

/// Saved links, then recent opens, in one short scrolling list.
struct DeeplinkEntryListView: View {
	let groups: DeeplinkEntryGroups
	let isOpenEnabled: Bool
	let actions: DeeplinkEntryActions

	var body: some View {
		List {
			if !groups.saved.isEmpty {
				Section("Saved") {
					ForEach(groups.saved) { row in
						DeeplinkEntryRowView(row: row, isOpenEnabled: isOpenEnabled, actions: actions)
					}
				}
			}
			if !groups.recent.isEmpty {
				Section("Recent") {
					ForEach(groups.recent) { row in
						DeeplinkEntryRowView(row: row, isOpenEnabled: isOpenEnabled, actions: actions)
					}
				}
			}
		}
		.listStyle(.inset)
		.frame(maxHeight: TestForgeConstants.SimulatorControl.deeplinkListMaxHeight)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.deeplinkEntryList)
	}
}
