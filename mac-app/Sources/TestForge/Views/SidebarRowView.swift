import SwiftUI

/// A colored icon tile and the section name; the selected row grows its tile and turns bold.
struct SidebarRowView: View {
	let section: TestForgeSection
	let isSelected: Bool

	private var tileSize: CGFloat {
		isSelected ? SidebarConstants.selectedTileSize : SidebarConstants.tileSize
	}

	var body: some View {
		Label {
			Text(section.title)
				.fontWeight(isSelected ? .semibold : .regular)
		} icon: {
			Image(systemName: section.symbolName)
				.font(.system(size: tileSize * SidebarConstants.glyphShare, weight: .semibold))
				.foregroundStyle(.white)
				.frame(width: tileSize, height: tileSize)
				.background(section.tint.gradient, in: RoundedRectangle(cornerRadius: tileSize * SidebarConstants.cornerShare))
				.shadow(color: isSelected ? .black.opacity(SidebarConstants.selectedShadowOpacity) : .clear, radius: 1, y: 1)
				.frame(width: SidebarConstants.selectedTileSize, height: SidebarConstants.selectedTileSize)
				.accessibilityHidden(true)
		}
		.padding(.vertical, SidebarConstants.rowPadding)
		.animation(.easeOut(duration: SidebarConstants.selectionAnimation), value: isSelected)
	}
}
