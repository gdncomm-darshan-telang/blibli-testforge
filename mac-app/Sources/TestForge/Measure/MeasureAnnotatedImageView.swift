import SwiftUI

/// The snapshot as an image: the cropped screenshot with the view's box, its spacing in numbers and the pins; the export
/// adds the numbered notes underneath. `displayScale` sizes the preview; the export renders at 1 and the device density.
struct MeasureAnnotatedImageView: View {
	let content: MeasureAnnotatedContent
	let displayScale: CGFloat
	var onTapImage: ((CGPoint) -> Void)?

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			annotatedScreenshot
			if content.showsNotes {
				notesList
			}
		}
		.background(Color.white)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.measureSnapshotImage)
	}

	private var crop: CGRect {
		content.draft.cropRect
	}

	private var annotatedScreenshot: some View {
		ZStack(alignment: .topLeading) {
			Image(nsImage: content.draft.image)
				.resizable()
				.frame(width: content.draft.screenSize.width * displayScale, height: content.draft.screenSize.height * displayScale)
				.offset(x: -crop.minX * displayScale, y: -crop.minY * displayScale)
			Rectangle()
				.strokeBorder(TestForgeConstants.MeasureSnapshot.elementColor, lineWidth: TestForgeConstants.MeasureSnapshot.elementLineWidth)
				.frame(width: content.draft.elementFrame.width * displayScale, height: content.draft.elementFrame.height * displayScale)
				.offset(local(content.draft.elementFrame.origin))
			ForEach(content.draft.gaps) { gap in
				gapLine(gap: gap)
			}
			ForEach(content.pins) { pin in
				MeasurePinBadgeView(number: pin.id)
					.offset(pinOffset(pin.position))
			}
		}
		.frame(width: crop.width * displayScale, height: crop.height * displayScale, alignment: .topLeading)
		.clipped()
		.contentShape(Rectangle())
		.onTapGesture(coordinateSpace: .local) { location in
			let devicePoint = CGPoint(x: crop.minX + location.x / displayScale, y: crop.minY + location.y / displayScale)
			onTapImage?(devicePoint)
		}
	}

	private func gapLine(gap: MeasureGap) -> some View {
		let start = local(gap.start)
		let end = local(gap.end)
		let middle = CGSize(width: (start.width + end.width) / 2, height: (start.height + end.height) / 2)
		return ZStack(alignment: .topLeading) {
			Path { path in
				path.move(to: CGPoint(x: start.width, y: start.height))
				path.addLine(to: CGPoint(x: end.width, y: end.height))
			}
			.stroke(TestForgeConstants.MeasureSnapshot.gapColor, lineWidth: TestForgeConstants.MeasureSnapshot.gapLineWidth)
			Text(MeasureFormatting.points(gap.distance))
				.font(.system(size: TestForgeConstants.MeasureSnapshot.labelFontSize, weight: .bold).monospacedDigit())
				.foregroundStyle(Color.white)
				.padding(.horizontal, TestForgeConstants.Spacing.small)
				.background(Capsule().fill(TestForgeConstants.MeasureSnapshot.gapColor))
				.fixedSize()
				.position(x: middle.width, y: middle.height)
		}
	}

	private var notesList: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text(content.draft.elementTitle)
				.font(.system(size: TestForgeConstants.MeasureSnapshot.titleFontSize, weight: .semibold))
			ForEach(content.pins) { pin in
				HStack(alignment: .top, spacing: TestForgeConstants.Spacing.small) {
					MeasurePinBadgeView(number: pin.id)
					Text(pin.note.isEmpty ? " " : pin.note)
						.font(.system(size: TestForgeConstants.MeasureSnapshot.noteFontSize))
						.fixedSize(horizontal: false, vertical: true)
				}
			}
			Text(content.draft.capturedAt.formatted(date: .abbreviated, time: .shortened))
				.font(.system(size: TestForgeConstants.MeasureSnapshot.footnoteFontSize))
				.foregroundStyle(Color.gray)
		}
		.foregroundStyle(Color.black)
		.padding(TestForgeConstants.Spacing.medium)
		.frame(width: crop.width * displayScale, alignment: .leading)
	}

	private func local(_ point: CGPoint) -> CGSize {
		CGSize(width: (point.x - crop.minX) * displayScale, height: (point.y - crop.minY) * displayScale)
	}

	/// Centres the badge on the point that was clicked.
	private func pinOffset(_ point: CGPoint) -> CGSize {
		let local = local(point)
		let half = TestForgeConstants.MeasureSnapshot.pinSize / 2
		return CGSize(width: local.width - half, height: local.height - half)
	}
}
