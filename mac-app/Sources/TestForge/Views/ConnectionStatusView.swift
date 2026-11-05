import SwiftUI

/// Toolbar pill for the live-updates connection, with Reconnect when it has dropped.
struct ConnectionStatusView: View {
	let status: ConnectionStatusModel
	let onReconnect: () -> Void

	var body: some View {
		HStack(spacing: TestForgeConstants.Spacing.small) {
			Label(status.title, systemImage: status.symbolName)
				.foregroundStyle(status.isHealthy ? Color.green : Color.secondary)
				.labelStyle(.titleAndIcon)
			if status.canReconnect {
				Button("Reconnect", action: onReconnect)
					.accessibilityIdentifier(TestForgeConstants.Accessibility.reconnectButton)
			}
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier(TestForgeConstants.Accessibility.connectionStatus)
	}
}
