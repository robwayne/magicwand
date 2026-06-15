import SwiftUI

@main
struct MagicWandApp: App {
    /// Holds the list of previously-paired TVs and the active connection.
    @State private var tvStore = TVStore()
    @State private var connection = TVConnectionManager()
    @State private var appsStore = AppsStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environment(tvStore)
                .environment(connection)
                .environment(appsStore)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .onChange(of: scenePhase) { _, phase in
            // The control socket drops while backgrounded; reconnect on return.
            if phase == .active {
                connection.reconnectAfterForeground(using: tvStore)
            }
        }
    }
}
