import SwiftUI

struct AnnotationCanvasStyle {
	let tool: AnnotationTool
	let color: AnnotationColor
}

/// The screenshot fitted to the panel with marks drawn over it; a drag adds one mark in the chosen tool and colour.
struct AnnotationCanvasView: View {
	let image: NSImage
	let strokes: [AnnotationStroke]
	let style: AnnotationCanvasStyle
	let addStroke: (AnnotationStroke) -> Void
	@State private var currentStroke: AnnotationStroke?

	var body: some View {
		GeometryReader { geometry in
			let imageRect = fittedRect(container: geometry.size)
			ZStack(alignment: .topLeading) {
				Image(nsImage: image)
					.resizable()
					.interpolation(.high)
					.frame(width: imageRect.width, height: imageRect.height)
					.offset(x: imageRect.minX, y: imageRect.minY)
				Canvas { context, _ in
					let lineWidth = AnnotationRenderer.lineWidth(for: imageRect.size)
					for stroke in strokes + [currentStroke].compactMap({ $0 }) {
						let path = Path(AnnotationRenderer.path(for: stroke, in: imageRect))
						let strokeStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
						context.stroke(path, with: .color(Color(nsColor: stroke.color.nsColor)), style: strokeStyle)
					}
				}
			}
			.contentShape(Rectangle())
			.gesture(drawGesture(imageRect: imageRect))
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text("Screenshot to annotate"))
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsMediaCanvas)
	}

	private func drawGesture(imageRect: CGRect) -> some Gesture {
		DragGesture(minimumDistance: 0)
			.onChanged { value in
				let point = normalized(location: value.location, in: imageRect)
				if var stroke = currentStroke {
					stroke.points = style.tool == .pen ? stroke.points + [point] : [stroke.points.first ?? point, point]
					currentStroke = stroke
				} else {
					currentStroke = AnnotationStroke(tool: style.tool, color: style.color, points: [point])
				}
			}
			.onEnded { _ in
				if let currentStroke,
					currentStroke.points.count > 1 {
					addStroke(currentStroke)
				}
				currentStroke = nil
			}
	}

	private func normalized(location: CGPoint, in rect: CGRect) -> CGPoint {
		let x = (location.x - rect.minX) / max(rect.width, 1)
		let y = (location.y - rect.minY) / max(rect.height, 1)
		return CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
	}

	private func fittedRect(container: CGSize) -> CGRect {
		guard image.size.width > 0,
			image.size.height > 0
		else {
			return CGRect(origin: .zero, size: container)
		}
		let scale = min(container.width / image.size.width, container.height / image.size.height)
		let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
		return CGRect(x: (container.width - size.width) / 2, y: (container.height - size.height) / 2, width: size.width, height: size.height)
	}
}
