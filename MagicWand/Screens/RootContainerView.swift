import SwiftUI

/// Top-level coordinator. Shows the onboarding/connection flow until a TV is connected,
/// then reveals the main tabbed interface (Casting · Remote · Library).
struct RootContainerView: View {
    @Environment(TVStore.self) private var store
    @Environment(TVConnectionManager.self) private var connection

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if connection.status.isConnected {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingFlowView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: connection.status)
        .onAppear {
            // Persist successful pairings into local storage.
            connection.onPaired = { device in
                store.markConnected(device, clientKey: device.clientKey)
            }
        }
    }
}
