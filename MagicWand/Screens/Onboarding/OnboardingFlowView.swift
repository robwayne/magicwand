import SwiftUI

/// Drives the connection onboarding across its three screens:
/// 1. Searching ("Setting up")  2. Select your TV  3. Enter PIN (pairing).
///
/// Local `step` handles the search → select transition; the connection manager's
/// `status` drives the move into pairing and out to the main app.
struct OnboardingFlowView: View {
    @Environment(TVConnectionManager.self) private var connection

    enum Step { case searching, select, pairing }
    @State private var step: Step = .searching

    var body: some View {
        ZStack {
            Theme.onboardingGradient.ignoresSafeArea()

            switch step {
            case .searching:
                SearchingView()
                    .transition(.opacity)
            case .select:
                SelectTVView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .pairing:
                PairingView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
        .onAppear { beginSearch() }
        .onChange(of: connection.status) { _, newValue in
            react(to: newValue)
        }
    }

    private func beginSearch() {
        step = .searching
        connection.startDiscovery()
        // Give the scan a few seconds of "Setting up" before showing the list,
        // matching the reference flow.
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            if step == .searching { withAnimation { step = .select } }
        }
    }

    private func react(to status: TVConnectionManager.Status) {
        switch status {
        case .awaitingPIN:
            step = .pairing
        case .connecting:
            break
        case .failed:
            // Drop back to the selection list so the user can retry.
            if step == .pairing { step = .select }
        case .disconnected:
            if step == .pairing { step = .select }
        default:
            break
        }
    }
}
