import SwiftUI

/// Drives the connection onboarding: 1. Select your TV  2. Enter PIN (pairing).
///
/// Local `step` handles the select → pairing move via the connection manager's `status`.
/// Discovery starts immediately and the selection screen shows its own searching state,
/// so there's no separate "Setting up" loading screen.
struct OnboardingFlowView: View {
    @Environment(TVConnectionManager.self) private var connection

    enum Step { case select, pairing }
    @State private var step: Step = .select

    var body: some View {
        ZStack {
            Theme.onboardingGradient.ignoresSafeArea()

            switch step {
            case .select:
                SelectTVView()
                    .transition(.opacity)
            case .pairing:
                PairingView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
        .onAppear { connection.startDiscovery() }
        .onChange(of: connection.status) { _, newValue in
            react(to: newValue)
        }
    }

    private func react(to status: TVConnectionManager.Status) {
        switch status {
        case .awaitingPIN:
            step = .pairing
        case .failed, .disconnected:
            // Drop back to the selection list so the user can retry.
            if step == .pairing { step = .select }
        default:
            break
        }
    }
}
