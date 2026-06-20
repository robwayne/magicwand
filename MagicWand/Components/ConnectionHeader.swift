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
                    .foregroundStyle(statusColor)
            }
            Spacer()
            RefreshConnectionButton()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// "On • Connected" / "Off • Connected" / "Off • Not Connected", plus transient states.
    private var statusText: String {
        switch connection.status {
        case .connected:
            let power = connection.powerState == .on ? "On" : "Off"
            return "\(power) • Connected"
        case .connecting: return "Connecting…"
        case .awaitingPIN: return "Pairing…"
        case .discovering: return "Searching…"
        case .failed, .disconnected: return "Off • Not Connected"
        }
    }

    private var statusColor: Color {
        switch connection.status {
        case .connected:
            return connection.powerState == .on ? .green : Theme.textSecondary
        case .connecting, .awaitingPIN, .discovering:
            return Theme.textSecondary
        case .failed, .disconnected:
            return Theme.danger
        }
    }
}
