import SwiftUI

/// Breakpoints tab: add bar and bubble switch on top, breakpoints and held calls on the left, the selected held call on the right.
struct NetworkBreakpointsSectionView<ViewModel: NetworkBreakpointsPresenting>: View {
	@ObservedObject var viewModel: ViewModel

	var body: some View {
		VStack(spacing: 0) {
			addBar
			Divider()
			HStack(spacing: 0) {
				list
					.frame(width: NetworkConsoleConstants.Breakpoints.listWidth)
				Divider()
				editorPane
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.breakpoints)
	}

	@ViewBuilder
	private var addBar: some View {
		HStack(spacing: TestForgeConstants.Spacing.medium) {
			TextField("Endpoint to hold, e.g. GET /backend/content-api/flashsale", text: $viewModel.endpointText)
				.textFieldStyle(.roundedBorder)
				.onSubmit(viewModel.add)
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.breakpointEndpointField)
			Picker("Hold", selection: $viewModel.stage) {
				ForEach(NetworkBreakpointStage.allCases) { stage in
					Text(stage.title).tag(stage)
				}
			}
			.fixedSize()
			.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.breakpointStagePicker)
			Toggle("Once", isOn: $viewModel.isOneShot)
				.toggleStyle(.checkbox)
				.help("Stop holding after the first call")
				.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.breakpointOnceToggle)
			Button(action: viewModel.add) {
				ActionProgressLabel(
					title: String(localized: "Add"),
					busyTitle: String(localized: "Adding…"),
					isBusy: viewModel.runningAction == .add
				)
			}
			.disabled(!viewModel.canAdd)
			.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.breakpointAddButton)
			Divider()
				.frame(height: NetworkConsoleConstants.Breakpoints.barDividerHeight)
			bubbleMenu
		}
		.padding(TestForgeConstants.Spacing.medium)
		if let failure = viewModel.actionFailure {
			Label(failure.message, systemImage: "exclamationmark.triangle")
				.font(.caption)
				.foregroundStyle(.red)
				.textSelection(.enabled)
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding([.horizontal, .bottom], TestForgeConstants.Spacing.medium)
				.accessibilityIdentifier(TestForgeConstants.Accessibility.networkBreakpointFailure)
		}
	}

	@ViewBuilder
	private var bubbleMenu: some View {
		if case .bubble(let isHidden) = viewModel.runningAction {
			HStack(spacing: TestForgeConstants.Spacing.small) {
				ProgressView()
					.controlSize(.small)
				Text(isHidden ? String(localized: "Hiding bubble…") : String(localized: "Showing bubble…"))
			}
			.accessibilityElement(children: .combine)
			.accessibilityIdentifier(TestForgeConstants.Accessibility.networkBubbleProgress)
		} else {
			Menu("Bubble", systemImage: "circle.dashed") {
				Button("Hide bubble") {
					viewModel.setBubble(isHidden: true)
				}
				Button("Show bubble") {
					viewModel.setBubble(isHidden: false)
				}
			}
			.fixedSize()
			.disabled(viewModel.isWorking)
			.help("The NetworkLens bubble in the app — hide it so it never covers what a test taps")
			.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.bubbleMenu)
		}
	}

	@ViewBuilder
	private var list: some View {
		if let display = viewModel.state.content {
			let indexedHeld = Array(display.held.enumerated())
			let indexedBreakpoints = Array(display.breakpoints.enumerated())
			List(selection: $viewModel.selectedHeldId) {
				Section {
					ForEach(indexedHeld, id: \.element.id) { index, held in
						NetworkHeldCallRowView(held: held, index: index)
							.tag(held.id)
					}
				} header: {
					heldHeader(count: display.held.count)
				}
				Section("Breakpoints") {
					ForEach(indexedBreakpoints, id: \.element.id) { index, breakpoint in
						let control = NetworkBreakpointRowControl(
							isRemoving: viewModel.runningAction == .remove(id: breakpoint.id),
							isDisabled: viewModel.isWorking
						) {
							viewModel.remove(id: breakpoint.id)
						}
						NetworkBreakpointRowView(breakpoint: breakpoint, index: index, control: control)
							.selectionDisabled()
					}
				}
			}
			.listStyle(.inset)
		} else if viewModel.state == .notLoaded {
			NetworkPlaceholderView(phase: .loading)
		} else if let phase = NetworkPlaceholderPhase(state: viewModel.state) {
			NetworkPlaceholderView(phase: phase)
		}
	}

	@ViewBuilder
	private func heldHeader(count: Int) -> some View {
		HStack {
			Text("Held now · \(count)")
			Spacer()
			Button(action: viewModel.continueAll) {
				ActionProgressLabel(
					title: String(localized: "Continue all"),
					busyTitle: String(localized: "Continuing…"),
					isBusy: viewModel.runningAction == .continueAll
				)
			}
			.buttonStyle(.borderless)
			.disabled(count == 0 || viewModel.isWorking)
			.accessibilityIdentifier(NetworkConsoleConstants.Accessibility.heldContinueAllButton)
		}
	}

	@ViewBuilder
	private var editorPane: some View {
		if let held = viewModel.selectedHeld {
			NetworkHeldCallEditorView(viewModel: viewModel, held: held)
		} else {
			NetworkPlaceholderView(phase: .empty(String(localized: "Nothing held — a call to a breakpointed endpoint stops here until you let it go")))
		}
	}
}
