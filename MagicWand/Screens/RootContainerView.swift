import SwiftUI

/// Top-level coordinator. On first launch (no saved TV) it shows the onboarding flow.
/// On subsequent launches it lands on the main app and silently reconnects to the most
/// recently used TV using its stored client-key.
struct RootContainerView: View {
    @Environment(TVStore.self) private var store
    @Environment(TVConnectionManager.self) private var connection

    @State private var didBootstrap = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch connection.route {
            case .main:
                MainTabView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingFlowView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: connection.route)
        .onAppear {
            guard !didBootstrap else { return }
            didBootstrap = true

            // Persist successful pairings into local storage.
            connection.onPaired = { device in
                store.markConnected(device, clientKey: device.clientKey)
            }
            // Land on the remote and reconnect to the last TV, or onboard if there's none.
            connection.bootstrap(using: store)
        }
    }
}
