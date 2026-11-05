import SwiftUI

enum ScanMode: String, CaseIterable, Identifiable {
	case flowMap
	case surfaces

	var id: String { rawValue }

	var title: LocalizedStringKey {
		switch self {
			case .flowMap:
				return "Record macro"
			case .surfaces:
				return "Screen surfaces"
		}
	}
}

/// Scan's two ways in: the flow map (taps and screens, D-117) and the named screen surfaces from the harness (D-086).
struct ScanContainerView: View {
	@ObservedObject var scanViewModel: ScanSectionViewModel
	@ObservedObject var flowMapViewModel: FlowMapViewModel
	@State private var mode: ScanMode = .flowMap

	var body: some View {
		VStack(spacing: 0) {
			Picker("Scan mode", selection: $mode) {
				ForEach(ScanMode.allCases) { scanMode in
					Text(scanMode.title).tag(scanMode)
				}
			}
			.pickerStyle(.segmented)
			.labelsHidden()
			.fixedSize()
			.padding(TestForgeConstants.Spacing.medium)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.scanModePicker)
			Divider()
			switch mode {
				case .flowMap:
					FlowMapSectionView(viewModel: flowMapViewModel)
				case .surfaces:
					ScanSectionView(viewModel: scanViewModel)
			}
		}
	}
}
