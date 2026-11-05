import AppKit
import AVFoundation
import QuartzCore

/// Each card and subtitle is a full-frame bitmap shown in its time window.
/// Bitmaps, not text or shape layers: the video exporter dropped text and filled shapes solid.
struct DemoOverlayBuilder {
	let renderSize: CGSize

	/// Rendered pixels per device point.
	let pointScale: CGFloat

	func overlay(for script: DemoScript) -> CALayer {
		let root = CALayer()
		root.frame = CGRect(origin: .zero, size: renderSize)
		let painter = DemoPainter(size: renderSize, pointScale: pointScale)
		for cue in script.cues {
			if let image = painter.image(cue: cue) {
				root.addSublayer(visible(image, from: cue.start, to: cue.end))
			}
		}
		for card in [script.intro, script.outro] {
			if let image = painter.image(card: card) {
				root.addSublayer(visible(image, from: card.start, to: card.end))
			}
		}
		return root
	}

	/// Hidden outside `start…end`: an opacity animation the exporter plays on the video's clock.
	private func visible(_ image: CGImage, from start: Double, to end: Double) -> CALayer {
		let layer = CALayer()
		layer.frame = CGRect(origin: .zero, size: renderSize)
		layer.contents = image
		layer.opacity = 0
		let animation = CABasicAnimation(keyPath: "opacity")
		animation.fromValue = 1
		animation.toValue = 1
		animation.beginTime = AVCoreAnimationBeginTimeAtZero + start
		animation.duration = max(end - start, 0.1)
		animation.isRemovedOnCompletion = false
		animation.fillMode = .removed
		layer.add(animation, forKey: "visible")
		return layer
	}
}

struct DemoTextStyle {
	let fontSize: CGFloat
	let weight: NSFont.Weight
	let color: NSColor
	var alignment: NSTextAlignment = .natural
}

/// Draws overlays top-left origin, in rendered pixels.
struct DemoPainter {
	let size: CGSize
	let pointScale: CGFloat

	private var width: CGFloat {
		size.width
	}

	private var height: CGFloat {
		size.height
	}

	func image(cue: DemoCue) -> CGImage? {
		draw { _ in
			let pointerRect = cue.pointer.map { drawPointer($0) }
			let style = DemoTextStyle(fontSize: width * DemoLayout.captionFontSize, weight: .semibold, color: .white)
			let box = boxSize(cue.text, style: style, maxWidth: width * 0.9)
			let isPointerLow = (pointerRect?.maxY ?? 0) > height * 0.68
			let originY = isPointerLow ? height * 0.07 : height - box.height - height * 0.05
			let origin = CGPoint(x: (width - box.width) / 2, y: originY)
			let frame = CGRect(origin: origin, size: CGSize(width: width * 0.9, height: 0))
			drawBox(cue.text, style: style, background: DemoLayout.captionBackground, frame: frame)
		}
	}

	func image(card: DemoCard) -> CGImage? {
		if let outcome = card.outcome {
			return resultImage(card: card, outcome: outcome)
		}
		return draw { context in
			context.setFillColor(DemoLayout.cardBackground.cgColor)
			context.fill(CGRect(origin: .zero, size: size))
			let textWidth = width * 0.84
			let left = width * 0.08
			var cursorY = height * 0.16
			let titleStyle = DemoTextStyle(fontSize: width * DemoLayout.cardTitleFontSize, weight: .bold, color: .white)
			let headingStyle = DemoTextStyle(fontSize: width * DemoLayout.cardHeadingFontSize, weight: .bold, color: DemoLayout.accent)
			let bodyStyle = DemoTextStyle(fontSize: width * DemoLayout.cardBodyFontSize, weight: .regular, color: .white)
			cursorY += drawText(card.title, style: titleStyle, at: CGPoint(x: left, y: cursorY), maxWidth: textWidth) + height * 0.04
			for section in card.sections {
				cursorY += drawText(section.heading.uppercased(), style: headingStyle, at: CGPoint(x: left, y: cursorY), maxWidth: textWidth) + height * 0.008
				cursorY += drawText(section.body, style: bodyStyle, at: CGPoint(x: left, y: cursorY), maxWidth: textWidth) + height * 0.035
			}
		}
	}

	/// Same layout as the live overlay's result card: centered check or cross, colored verdict, then the case.
	private func resultImage(card: DemoCard, outcome: DemoOutcome) -> CGImage? {
		draw { context in
			context.setFillColor(DemoLayout.cardBackground.cgColor)
			context.fill(CGRect(origin: .zero, size: size))
			let tint = DemoLayout.color(for: outcome)
			let textWidth = width * DemoLayout.resultTextWidth
			let left = (width - textWidth) / 2
			let titleStyle = DemoTextStyle(fontSize: width * DemoLayout.resultTitleFontSize, weight: .bold, color: tint, alignment: .center)
			let headingStyle = DemoTextStyle(
				fontSize: width * DemoLayout.cardHeadingFontSize,
				weight: .semibold,
				color: NSColor.white.withAlphaComponent(0.65),
				alignment: .center
			)
			let bodyStyle = DemoTextStyle(fontSize: width * DemoLayout.cardBodyFontSize, weight: .regular, color: .white, alignment: .center)
			let symbolSize = width * DemoLayout.resultSymbolSize
			let gap = width * DemoLayout.resultSpacing
			let sectionsHeight = card.sections.reduce(CGFloat(0)) { total, section in
				let heading = measure(section.heading.uppercased(), style: headingStyle, maxWidth: textWidth).height
				return total + heading + measure(section.body, style: bodyStyle, maxWidth: textWidth).height + gap
			}
			let titleHeight = measure(card.title, style: titleStyle, maxWidth: textWidth).height
			var cursorY = (height - symbolSize - gap - titleHeight - gap - sectionsHeight) / 2
			drawSymbol(outcome.symbolName, tint: tint, frame: CGRect(x: (width - symbolSize) / 2, y: cursorY, width: symbolSize, height: symbolSize))
			cursorY += symbolSize + gap
			cursorY += drawText(card.title, style: titleStyle, at: CGPoint(x: left, y: cursorY), maxWidth: textWidth) + gap
			for section in card.sections {
				cursorY += drawText(section.heading.uppercased(), style: headingStyle, at: CGPoint(x: left, y: cursorY), maxWidth: textWidth) + height * 0.008
				cursorY += drawText(section.body, style: bodyStyle, at: CGPoint(x: left, y: cursorY), maxWidth: textWidth) + gap
			}
		}
	}

	private func drawSymbol(_ name: String, tint: NSColor, frame: CGRect) {
		let configuration = NSImage.SymbolConfiguration(pointSize: frame.height, weight: .regular)
			.applying(NSImage.SymbolConfiguration(paletteColors: [.white, tint]))
		guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration) else {
			return
		}
		symbol.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
	}

	// MARK: - Drawing

	/// A transparent full-frame bitmap whose drawing coordinates start at the top left.
	private func draw(_ body: (CGContext) -> Void) -> CGImage? {
		guard let context = CGContext(
			data: nil,
			width: Int(size.width),
			height: Int(size.height),
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else {
			return nil
		}
		context.translateBy(x: 0, y: size.height)
		context.scaleBy(x: 1, y: -1)
		let previous = NSGraphicsContext.current
		NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
		body(context)
		NSGraphicsContext.current = previous
		return context.makeImage()
	}

	/// Returns the outlined rect so the subtitle can move out of its way.
	private func drawPointer(_ pointer: DemoPointer) -> CGRect {
		let inset = -width * DemoLayout.pointerInset
		let source = pointer.rect
		let rect = CGRect(x: source.minX * pointScale, y: source.minY * pointScale, width: source.width * pointScale, height: source.height * pointScale)
			.insetBy(dx: inset, dy: inset)
		let color = DemoLayout.color(for: pointer.style)
		let corner = width * DemoLayout.pointerCorner
		let outline = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
		color.withAlphaComponent(0.14).setFill()
		outline.fill()
		color.setStroke()
		outline.lineWidth = width * DemoLayout.pointerLineWidth
		outline.stroke()
		if pointer.style == .action {
			let radius = width * DemoLayout.tapDotRadius
			color.withAlphaComponent(0.75).setFill()
			NSBezierPath(ovalIn: CGRect(x: rect.midX - radius, y: rect.midY - radius, width: radius * 2, height: radius * 2)).fill()
		}
		if let badge = pointer.badge {
			let style = DemoTextStyle(fontSize: width * DemoLayout.badgeFontSize, weight: .bold, color: .white)
			let box = boxSize(badge, style: style, maxWidth: width * 0.8)
			let gap = width * 0.02
			let originY = rect.minY - box.height - gap > 0 ? rect.minY - box.height - gap : rect.maxY + gap
			let originX = min(max(rect.minX, width * 0.03), width - box.width - width * 0.03)
			drawBox(badge, style: style, background: color, frame: CGRect(x: originX, y: originY, width: width * 0.8, height: 0))
		}
		return rect
	}

	private func boxSize(_ text: String, style: DemoTextStyle, maxWidth: CGFloat) -> CGSize {
		let padding = style.fontSize * 0.55
		let textSize = measure(text, style: style, maxWidth: maxWidth - padding * 2)
		return CGSize(width: textSize.width + padding * 2, height: textSize.height + padding * 1.4)
	}

	/// `frame` holds the box's origin and the widest it may grow.
	private func drawBox(_ text: String, style: DemoTextStyle, background: NSColor, frame: CGRect) {
		let origin = frame.origin
		let maxWidth = frame.width
		let padding = style.fontSize * 0.55
		let box = CGRect(origin: origin, size: boxSize(text, style: style, maxWidth: maxWidth))
		background.setFill()
		NSBezierPath(roundedRect: box, xRadius: style.fontSize * 0.5, yRadius: style.fontSize * 0.5).fill()
		_ = drawText(text, style: style, at: CGPoint(x: origin.x + padding, y: origin.y + padding * 0.7), maxWidth: maxWidth - padding * 2)
	}

	/// Returns the height drawn.
	private func drawText(_ text: String, style: DemoTextStyle, at origin: CGPoint, maxWidth: CGFloat) -> CGFloat {
		let textSize = measure(text, style: style, maxWidth: maxWidth)
		let frame = CGRect(origin: origin, size: CGSize(width: maxWidth, height: textSize.height))
		attributed(text, style: style).draw(with: frame, options: [.usesLineFragmentOrigin, .usesFontLeading])
		return textSize.height
	}

	private func measure(_ text: String, style: DemoTextStyle, maxWidth: CGFloat) -> CGSize {
		let limit = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
		let bounds = attributed(text, style: style).boundingRect(with: limit, options: [.usesLineFragmentOrigin, .usesFontLeading])
		return CGSize(width: ceil(bounds.width) + 2, height: ceil(bounds.height) + 2)
	}

	private func attributed(_ text: String, style: DemoTextStyle) -> NSAttributedString {
		let paragraph = NSMutableParagraphStyle()
		paragraph.lineBreakMode = .byWordWrapping
		paragraph.alignment = style.alignment
		let font = NSFont.systemFont(ofSize: style.fontSize, weight: style.weight)
		return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: style.color, .paragraphStyle: paragraph])
	}
}

/// Sizes as fractions of the rendered width, so a demo reads the same at any resolution.
enum DemoLayout {
	static let captionFontSize: CGFloat = 0.052
	static let badgeFontSize: CGFloat = 0.038
	static let cardTitleFontSize: CGFloat = 0.066
	static let cardHeadingFontSize: CGFloat = 0.032
	static let cardBodyFontSize: CGFloat = 0.048
	static let pointerInset: CGFloat = 0.012
	static let pointerCorner: CGFloat = 0.02
	static let pointerLineWidth: CGFloat = 0.0045
	static let tapDotRadius: CGFloat = 0.03
	static let resultSymbolSize: CGFloat = 0.22
	static let resultTitleFontSize: CGFloat = 0.074
	static let resultSpacing: CGFloat = 0.035
	static let resultTextWidth: CGFloat = 0.84
	static let accent = NSColor(srgbRed: 0.55, green: 0.78, blue: 1, alpha: 1)
	static let captionBackground = NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.8)
	static let cardBackground = NSColor(srgbRed: 0.04, green: 0.06, blue: 0.1, alpha: 0.92)

	static func color(for outcome: DemoOutcome) -> NSColor {
		switch outcome {
			case .passed:
				return color(for: DemoPointerStyle.passed)
			case .failed:
				return color(for: DemoPointerStyle.failed)
			case .undecided:
				return NSColor(srgbRed: 1, green: 0.62, blue: 0.04, alpha: 1)
		}
	}

	static func color(for style: DemoPointerStyle) -> NSColor {
		switch style {
			case .action:
				return NSColor(srgbRed: 1, green: 0.78, blue: 0.1, alpha: 1)
			case .checking:
				return accent
			case .passed:
				return NSColor(srgbRed: 0.2, green: 0.78, blue: 0.35, alpha: 1)
			case .failed:
				return NSColor(srgbRed: 0.95, green: 0.26, blue: 0.21, alpha: 1)
		}
	}
}
