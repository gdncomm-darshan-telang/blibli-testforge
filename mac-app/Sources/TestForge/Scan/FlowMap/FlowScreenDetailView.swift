import SwiftUI

struct FlowScreenDetailModel {
	let screen: FlowScreen
	let thumbnailURL: URL?
	let isCurrent: Bool
	let incoming: [FlowEdgeRowModel]
	let outgoing: [FlowEdgeRowModel]
	let saveFailure: String?
}

struct FlowScreenDetailActions {
	let rename: (String) -> Void
	let select: (String) -> Void
}

/// The selected screen: thumbnail, editable name, and every move into and out of it (click one to go to that screen).
struct FlowScreenDetailView: View {
	let model: FlowScreenDetailModel
	let actions: FlowScreenDetailActions
	@State private var name = ""

	var body: some View {
		ScrollView {
			HStack(alignment: .top, spacing: TestForgeConstants.Spacing.extraLarge) {
				thumbnail
				VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.large) {
					nameSection
					edgeSection(title: "Reached by", rows: model.incoming, emptyText: "The start screen, or reached without a recorded tap.")
					edgeSection(title: "Leads to", rows: model.outgoing, emptyText: "No recorded move out of this screen yet.")
				}
				.frame(maxWidth: .infinity, alignment: .leading)
			}
			.padding(TestForgeConstants.Spacing.large)
		}
		.onAppear {
			name = model.screen.name
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.flowMapDetail)
	}

	@ViewBuilder
	private var thumbnail: some View {
		if let thumbnailURL = model.thumbnailURL {
			AsyncImage(url: thumbnailURL) { phase in
				switch phase {
					case .success(let image):
						image
							.resizable()
							.scaledToFit()
							.clipShape(RoundedRectangle(cornerRadius: TestForgeConstants.FlowMap.thumbnailCornerRadius))
					case .failure:
						Image(systemName: "photo.badge.exclamationmark")
							.foregroundStyle(.secondary)
					default:
						ProgressView()
				}
			}
			.frame(maxHeight: TestForgeConstants.FlowMap.thumbnailMaxHeight)
		}
	}

	private var nameSection: some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			TextField("Screen name", text: $name)
				.textFieldStyle(.roundedBorder)
				.font(.title3)
				.onSubmit {
					actions.rename(name)
				}
				.accessibilityIdentifier(TestForgeConstants.Accessibility.flowMapNameField)
			if let saveFailure = model.saveFailure {
				Label(saveFailure, systemImage: "exclamationmark.triangle.fill")
					.font(.caption)
					.foregroundStyle(.red)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.flowMapDetailSaveFailure)
			}
			Text("\(model.screen.id) · \(model.screen.fingerprint.count) identifiers · visited \(model.screen.visitCount)×")
				.font(.caption)
				.foregroundStyle(.secondary)
			if model.isCurrent {
				Label("The Simulator is on this screen", systemImage: "location.fill")
					.font(.caption)
					.foregroundStyle(Color.accentColor)
			}
		}
	}

	private func edgeSection(title: LocalizedStringKey, rows: [FlowEdgeRowModel], emptyText: LocalizedStringKey) -> some View {
		VStack(alignment: .leading, spacing: TestForgeConstants.Spacing.small) {
			Text(title)
				.font(.headline)
			if rows.isEmpty {
				Text(emptyText)
					.font(.callout)
					.foregroundStyle(.secondary)
			}
			ForEach(rows) { row in
				Button {
					actions.select(row.screenId)
				} label: {
					HStack(spacing: TestForgeConstants.Spacing.small) {
						Image(systemName: "hand.tap")
						Text(row.actionText)
						Image(systemName: "arrow.right")
							.foregroundStyle(.secondary)
						Text(row.screenName)
							.fontWeight(.semibold)
						if let countText = row.countText {
							Text(countText)
								.foregroundStyle(.secondary)
						}
					}
				}
				.buttonStyle(.link)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.flowMapEdgePrefix + row.id)
			}
		}
	}
}
