import CoreGraphics
import Foundation

/// Folds layer boxes from the Color Blended Layers capture into the accessibility elements.
/// A box matching an element only lends it a corner radius; boxes inside a text element are its glyphs and are dropped.
/// A box that cuts into a line of text seen on screen is never a view either (D-143): text is never split into elements.
/// Icons are never split either (D-145): pieces inside an icon-sized box, strips on its edge and specks are its drawing.
/// Thin bars inside an icon-sized button or image are its strokes (an arrow's shaft); a page indicator's pill is kept.
enum LayerElementMerger {
	private static let matchOverlap: CGFloat = 0.85
	private static let minimumLongSide: CGFloat = 3
	private static let minimumShortSide: CGFloat = 1
	private static let textRole = "AXStaticText"
	private static let containmentSlack: CGFloat = 1
	private static let thinBarHeight: CGFloat = 6
	private static let iconSide: CGFloat = 48
	private static let iconRoles: Set<String> = ["AXButton", "AXImage"]

	/// The share of a box that may lie on a text line before the box counts as cutting the text.
	private static let textOverlapShare: CGFloat = 0.2

	/// A view inside an icon (the glyph in a round button) sits on its centre; drawing pieces don't.
	private static let centreTolerance: CGFloat = 1.5
	private static let stripThickness: CGFloat = 4
	private static let edgeTolerance: CGFloat = 1
	private static let speckLongSide: CGFloat = 9
	private static let speckShortSide: CGFloat = 6

	/// `textLines`: line boxes read from the screenshot (`TextRegionDetector`), in device points.
	static func merge(layers: [DetectedLayer], into elements: [MeasuredElement], textLines: [CGRect]) -> [MeasuredElement] {
		var merged = elements
		var nextId = (elements.map(\.id).max() ?? 0) + 1
		var candidates: [DetectedLayer] = []
		for layer in layers {
			if let matchIndex = merged.firstIndex(where: { overlapShare($0.frame, layer.frame) >= matchOverlap }) {
				if merged[matchIndex].cornerRadius == nil {
					merged[matchIndex].cornerRadius = layer.cornerRadius
				}
				continue
			}
			guard max(layer.frame.width, layer.frame.height) >= minimumLongSide,
				min(layer.frame.width, layer.frame.height) >= minimumShortSide,
				!isGlyph(layer: layer, elements: elements),
				!cutsText(layer: layer, textLines: textLines),
				!isIconStroke(layer: layer, elements: elements)
			else {
				continue
			}
			candidates.append(layer)
		}
		let icons = iconFrames(candidates: candidates, elements: elements)
		for layer in candidates where !isIconPiece(layer.frame, icons: icons) {
			merged.append(element(from: layer, id: nextId))
			nextId += 1
		}
		return merged
	}

	/// Icon-sized boxes: the layer pass's own and the icon buttons and images the accessibility tree reports.
	private static func iconFrames(candidates: [DetectedLayer], elements: [MeasuredElement]) -> [CGRect] {
		let layerIcons = candidates.map(\.frame).filter(isIconSized)
		let elementIcons = elements.filter { iconRoles.contains($0.role) }.map(\.frame).filter(isIconSized)
		return layerIcons + elementIcons
	}

	private static func isIconSized(_ frame: CGRect) -> Bool {
		frame.width <= iconSide && frame.height <= iconSide
	}

	private static func isIconPiece(_ box: CGRect, icons: [CGRect]) -> Bool {
		let isSpeck = max(box.width, box.height) < speckLongSide && min(box.width, box.height) < speckShortSide
		return isSpeck || icons.contains { icon in
			icon != box && (isOffCentreInside(box, icon: icon) || isEdgeStrip(box, icon: icon))
		}
	}

	private static func isOffCentreInside(_ box: CGRect, icon: CGRect) -> Bool {
		guard icon.insetBy(dx: -containmentSlack, dy: -containmentSlack).contains(box),
			box.area < icon.area
		else {
			return false
		}
		return abs(box.midX - icon.midX) > centreTolerance || abs(box.midY - icon.midY) > centreTolerance
	}

	/// A thin strip lying along an icon's edge, within its span, is the icon's shadow or stroke.
	private static func isEdgeStrip(_ box: CGRect, icon: CGRect) -> Bool {
		guard min(box.width, box.height) <= stripThickness else {
			return false
		}
		if box.width >= box.height {
			let isWithinSpan = box.minX >= icon.minX - edgeTolerance && box.maxX <= icon.maxX + edgeTolerance
			let touchesEdge = abs(box.minY - icon.maxY) <= edgeTolerance || abs(box.maxY - icon.minY) <= edgeTolerance
			return isWithinSpan && touchesEdge
		}
		let isWithinSpan = box.minY >= icon.minY - edgeTolerance && box.maxY <= icon.maxY + edgeTolerance
		let touchesEdge = abs(box.minX - icon.maxX) <= edgeTolerance || abs(box.maxX - icon.minX) <= edgeTolerance
		return isWithinSpan && touchesEdge
	}

	private static func isGlyph(layer: DetectedLayer, elements: [MeasuredElement]) -> Bool {
		elements.contains { element in
			element.role == textRole && element.frame.insetBy(dx: -containmentSlack, dy: -containmentSlack).contains(layer.frame)
		}
	}

	/// A box wrapping a whole line (a button, a chip, a card) is kept; one covering part of a line is glyph ink.
	private static func cutsText(layer: DetectedLayer, textLines: [CGRect]) -> Bool {
		textLines.contains { line in
			let shared = line.intersection(layer.frame)
			guard !shared.isNull,
				layer.frame.area > 0
			else {
				return false
			}
			let wrapsLine = layer.frame.insetBy(dx: -containmentSlack, dy: -containmentSlack).contains(line)
			return !wrapsLine && shared.area / layer.frame.area >= textOverlapShare
		}
	}

	private static func isIconStroke(layer: DetectedLayer, elements: [MeasuredElement]) -> Bool {
		guard layer.frame.height < thinBarHeight else {
			return false
		}
		return elements.contains { element in
			let frame = element.frame
			let isIconSized = frame.width <= iconSide && frame.height <= iconSide
			return iconRoles.contains(element.role) && isIconSized && frame.insetBy(dx: -containmentSlack, dy: -containmentSlack).contains(layer.frame)
		}
	}

	private static func element(from layer: DetectedLayer, id: Int) -> MeasuredElement {
		var element = MeasuredElement(
			id: id,
			identifier: "",
			role: "",
			label: "",
			frame: layer.frame,
			path: [],
			parentId: nil,
			childCount: 0
		)
		element.source = .layerColors
		element.cornerRadius = layer.cornerRadius
		return element
	}

	private static func overlapShare(_ first: CGRect, _ second: CGRect) -> CGFloat {
		let shared = first.intersection(second)
		guard !shared.isNull else {
			return 0
		}
		let union = first.area + second.area - shared.area
		return union > 0 ? shared.area / union : 0
	}
}
