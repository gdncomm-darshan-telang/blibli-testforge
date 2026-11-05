import AppKit

enum AnnotationTool: String, CaseIterable, Identifiable {
	case pen
	case arrow
	case box

	var id: String { rawValue }

	var title: LocalizedStringResource {
		switch self {
			case .pen:
				return "Pen"
			case .arrow:
				return "Arrow"
			case .box:
				return "Box"
		}
	}

	var systemImage: String {
		switch self {
			case .pen:
				return "scribble"
			case .arrow:
				return "arrow.up.right"
			case .box:
				return "rectangle"
		}
	}
}

enum AnnotationColor: String, CaseIterable, Identifiable {
	case red
	case yellow
	case green

	var id: String { rawValue }

	var title: LocalizedStringResource {
		switch self {
			case .red:
				return "Red"
			case .yellow:
				return "Yellow"
			case .green:
				return "Green"
		}
	}

	var nsColor: NSColor {
		switch self {
			case .red:
				return .systemRed
			case .yellow:
				return .systemYellow
			case .green:
				return .systemGreen
		}
	}
}

/// One mark on a screenshot; points are 0…1 of the image's width and height from the top left, so they survive any zoom.
struct AnnotationStroke: Equatable, Identifiable {
	let id = UUID()
	let tool: AnnotationTool
	let color: AnnotationColor
	var points: [CGPoint]
}
