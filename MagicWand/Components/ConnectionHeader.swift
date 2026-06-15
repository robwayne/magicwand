import SwiftUI

/// The header shown at the top of the Remote and Casting screens:
/// TV name, connection status, and an AirPlay route picker on the right.
struct ConnectionHeader: View {
    @Environment(TVConnectionManager.self) private var connection

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.activeDevice?.displayName ?? "LG TV UP7500PVG")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text(statusText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(connection.status.isConnected ? Theme.textSecondary : Theme.danger)
            }
            Spacer()
            RefreshConnectionButton()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var statusText: String {
        switch connection.status {
        case .connected: "Connected"
        case .connecting: "Connecting…"
        case .awaitingPIN: "Pairing…"
        case .discovering: "Searching…"
        case .failed: "Disconnected"
        case .disconnected: "Not Connected"
        }
    }
}
