import SwiftUI

struct TestDocumentHeaderView: View {
	let header: TestDocumentHeader
	let actions: TestDocumentHeaderActions

	var body: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			HStack(alignment: .top, spacing: TestForgeConstants.Spacing.medium) {
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
					Text(header.title)
						.font(.headline)
						.lineLimit(2)
						.help(header.title)
					Text(header.caseCountText)
						.font(.caption)
						.foregroundStyle(.secondary)
					buildLabel
				}
				Spacer()
				if header.isReloading {
					ProgressView()
						.controlSize(.small)
				}
			}
			// A narrow list (Split View beside the Simulator) drops the button titles instead of wrapping them letter by letter.
			ViewThatFits(in: .horizontal) {
				actionRow
					.labelStyle(.titleAndIcon)
				actionRow
					.labelStyle(.iconOnly)
			}
		}
		.padding(TestForgeConstants.Spacing.medium)
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.testsHeader)
	}

	private var actionRow: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			Button {
				actions.onRunAll()
			} label: {
				Label("Run all…", systemImage: "play.rectangle.on.rectangle")
			}
			.buttonStyle(.borderless)
			.help("Run every case the list shows as one batch; first shows what it will do and what could stop it")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsRunAllButton)
			.tutorialAnchor(.testsRunAllButton)
			Button {
				actions.onVerify()
			} label: {
				Label("Verify my changes…", systemImage: "checkmark.seal")
			}
			.buttonStyle(.borderless)
			.help("Replay the recorded cases that cover the code your branch changes")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsVerifyButton)
			.tutorialAnchor(.testsVerifyButton)
			if header.staleCount > 0 {
				Button {
					actions.onReplayStale()
				} label: {
					BusyActionLabel(title: replayStaleTitle, systemImage: "clock.arrow.circlepath", busyTitle: replayStaleBusyTitle)
				}
				.buttonStyle(.borderless)
				.help("Replay every stale case's recording on this build, without Claude")
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testsReplayStaleButton)
				.tutorialAnchor(.testsReplayStaleButton)
			}
			Button {
				actions.onExport()
			} label: {
				Image(systemName: "square.and.arrow.up")
			}
			.buttonStyle(.borderless)
			.help("Export the whole session: every case with its metadata, optionally with screenshots and videos")
			.accessibilityLabel("Export session")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsExportSessionButton)
			.tutorialAnchor(.testsExportSessionButton)
			Button {
				actions.onLoad()
			} label: {
				Image(systemName: "arrow.down.doc")
			}
			.buttonStyle(.borderless)
			.help("Load another test document")
			.accessibilityLabel("Load another test document")
			.accessibilityIdentifier(TestForgeConstants.Accessibility.testsLoadButton)
			.tutorialAnchor(.testsLoadButton)
		}
		.lineLimit(1)
	}

	private var replayStaleTitle: String {
		String(localized: "Replay stale (\(header.staleCount))")
	}

	private var replayStaleBusyTitle: String? {
		actions.isStartingStaleReplay ? String(localized: "Starting…") : nil
	}

	@ViewBuilder
	private var buildLabel: some View {
		if let buildText = header.buildText {
			Label(buildText, systemImage: header.isBuildUnverified ? "exclamationmark.triangle" : "hammer")
				.font(.caption)
				.foregroundStyle(header.isBuildUnverified ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
				.lineLimit(1)
				.truncationMode(.middle)
				.help(header.isBuildUnverified ? "The installed build isn't from the prepared code; results are stamped unverified" : buildText)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.testsBuildLabel)
				.tutorialAnchor(.testsBuildLabel)
		}
	}
}
