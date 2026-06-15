import SwiftUI

/// A refresh-connection button that reconnects to the active/last TV and reflects the
/// outcome: red while a triggered reconnect is failing (until it succeeds), then green
/// for 10 seconds on success before returning to the default colour.
struct RefreshConnectionButton: View {
    /// When set, refresh reconnects to this specific TV (Library rows). When nil, it
    /// reconnects to the active/last-used TV (remote header).
    var device: TVDevice? = nil

    @Environment(TVConnectionManager.self) private var connection
    @Environment(TVStore.self) private var store

    @State private var state: RefreshState = .idle
    @State private var monitoring = false

    enum RefreshState: Equatable {
        case idle, failed, success
        var color: Color {
            switch self {
            case .idle: Theme.textSecondary
            case .failed: Theme.danger
            case .success: .green
            }
        }
    }

    var body: some View {
        Button {
            Haptics.tap()
            monitoring = true
            state = .idle
            if let device {
                connection.connect(to: device)
            } else {
                connection.refreshConnection(using: store)
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(state.color)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless) // independent tap target inside list rows / links
        .accessibilityLabel("Refresh connection")
        .onChange(of: connection.status) { _, newValue in
            guard monitoring else { return }
            switch newValue {
            case .connected where device == nil || connection.activeDevice?.id == device?.id:
                state = .success
                monitoring = false
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(10))
                    if state == .success { state = .idle }
                }
            case .failed:
                state = .failed
            default:
                break
            }
        }
    }
}
