import SwiftUI

struct MeasureCanvasActions {
	let selectPoint: (CGPoint) -> Void
	let selectElement: (Int) -> Void
	let hoverPoint: (CGPoint?) -> Void
}

struct MeasureCanvasContent {
	let snapshot: MeasureSnapshot
	let selection: MeasureSelection?
	let hovered: MeasureComparison?

	/// Colour of the dashed borders for views without identifiers; nil hides them.
	let unidentifiedBorder: Color?
}

/// The capture scaled to fit, then zoomed; thin element boxes, and the selected element's spacing as lines with numbers.
struct MeasureCanvasView: View {
	let content: MeasureCanvasContent
	@Binding var zoom: CGFloat
	let actions: MeasureCanvasActions
	@State private var pinchStartZoom: CGFloat?

	var body: some View {
		GeometryReader { proxy in
			let scale = fittingScale(in: proxy.size) * zoom
			ScrollView([.horizontal, .vertical]) {
				canvas(scale: scale)
					.frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
			}
			.gesture(pinchGesture)
			.modifier(OptionScrollZoomModifier(zoom: $zoom))
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.measureCanvas)
		.tutorialAnchor(.measureCanvas)
	}

	@ViewBuilder
	private func canvas(scale: CGFloat) -> some View {
		let snapshot = content.snapshot
		let canvasSize = CGSize(width: snapshot.screenSize.width * scale, height: snapshot.screenSize.height * scale)
		ZStack(alignment: .topLeading) {
			Image(nsImage: snapshot.image)
				.resizable()
				.interpolation(zoom > 1 ? .none : .high)
				.frame(width: canvasSize.width, height: canvasSize.height)
			ForEach(snapshot.elements) { element in
				MeasureElementBoxView(
					frame: scaled(element.frame, by: scale),
					isSelected: element.id == content.selection?.element.id,
					kind: element.source == .layerColors ? .unidentified(border: content.unidentifiedBorder) : .reported
				)
					.accessibilityElement()
					.accessibilityLabel(Text(element.title))
					.accessibilityAddTraits(.isButton)
					.accessibilityAction {
						actions.selectElement(element.id)
					}
					.accessibilityIdentifier(TestForgeConstants.Accessibility.measureElementPrefix + "\(element.id)")
			}
			if let selection = content.selection {
				if let visible = selection.visibleContainer {
					MeasureVisibleContainerView(container: visible, scale: scale, color: content.unidentifiedBorder ?? .purple)
				}
				if let hovered = content.hovered {
					hoveredOverlay(hovered: hovered, scale: scale)
				} else {
					ForEach(selection.gaps) { gap in
						MeasureGapLineView(gap: gap, scale: scale)
					}
				}
			}
		}
		.frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
		.clipped()
		.contentShape(Rectangle())
		.gesture(SpatialTapGesture().onEnded { tap in
			let devicePoint = CGPoint(x: tap.location.x / scale, y: tap.location.y / scale)
			actions.selectPoint(devicePoint)
		})
		.onContinuousHover { phase in
			switch phase {
				case .active(let location):
					actions.hoverPoint(CGPoint(x: location.x / scale, y: location.y / scale))
				case .ended:
					actions.hoverPoint(nil)
			}
		}
		.padding(TestForgeConstants.Spacing.large)
	}

	/// Hover lines are blue, like Figma's Option-hover, so they read apart from the selection's own orange spacing.
	@ViewBuilder
	private func hoveredOverlay(hovered: MeasureComparison, scale: CGFloat) -> some View {
		let frame = scaled(hovered.frame, by: scale)
		Rectangle()
			.stroke(Color.blue, lineWidth: TestForgeConstants.Measure.hoveredLineWidth)
			.frame(width: frame.width, height: frame.height)
			.offset(x: frame.minX, y: frame.minY)
			.allowsHitTesting(false)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.measureHoveredBox)
		ForEach(hovered.gaps) { gap in
			MeasureGapLineView(gap: gap, scale: scale, tint: .blue)
		}
	}

	private var pinchGesture: some Gesture {
		MagnifyGesture()
			.onChanged { value in
				let startZoom = pinchStartZoom ?? zoom
				pinchStartZoom = startZoom
				let range = MeasureViewModel.zoomRange
				zoom = min(max(startZoom * value.magnification, range.lowerBound), range.upperBound)
			}
			.onEnded { _ in
				pinchStartZoom = nil
			}
	}

	/// Fit leaves room for the padding on both sides.
	private func fittingScale(in available: CGSize) -> CGFloat {
		let screenSize = content.snapshot.screenSize
		let inset = TestForgeConstants.Spacing.large * 2
		guard screenSize.width > 0,
			screenSize.height > 0
		else {
			return 1
		}
		return min((available.width - inset) / screenSize.width, (available.height - inset) / screenSize.height)
	}

	private func scaled(_ rect: CGRect, by scale: CGFloat) -> CGRect {
		CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
	}
}
