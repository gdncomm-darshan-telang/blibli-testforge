import SwiftUI

/// Subtitles over the Simulator: it only draws, never captures, and never changes the test.
struct ExplainOverlayView: View {
	let overlay: ExplainOverlay

	private var width: CGFloat {
		overlay.panelFrame.width
	}

	var body: some View {
		content
			.frame(width: overlay.panelFrame.width, height: overlay.panelFrame.height, alignment: .topLeading)
			.allowsHitTesting(false)
			.accessibilityIdentifier(ExplainOverlayConstants.Accessibility.overlay)
	}

	@ViewBuilder
	private var content: some View {
		switch overlay.content {
			case .card(let card):
				cardView(card)
			case .caption(let caption):
				captionLayer(caption)
		}
	}

	@ViewBuilder
	private func cardView(_ card: ExplainCard) -> some View {
		if let outcome = card.outcome {
			ExplainResultCardView(card: card, outcome: outcome, width: width)
		} else {
			ExplainCardView(card: card, width: width)
		}
	}

	private func captionLayer(_ caption: ExplainCaption) -> some View {
		ZStack(alignment: .topLeading) {
			Color.clear
			if let pointer = caption.pointer {
				ExplainPointerView(pointer: pointer, width: width)
			}
			if let text = caption.text,
				let placement = caption.placement {
				connector(caption: caption, placement: placement)
				ExplainCaptionView(content: ExplainCaptionContent(text: text, placement: placement, accent: caption.pointer?.color), width: width)
			}
		}
		.animation(.easeInOut(duration: ExplainOverlayConstants.Caption.moveSeconds), value: caption)
	}

	/// Runs on from the subtitle's tail to the element it describes, so the eye can follow from one to the other.
	@ViewBuilder
	private func connector(caption: ExplainCaption, placement: ExplainCaptionPlacement) -> some View {
		if let pointer = caption.pointer,
			let tail = placement.tail {
			ExplainConnectorView(tip: tail.tip, targetRect: pointer.outlineRect(width: width), color: pointer.color, width: width)
		}
	}
}
