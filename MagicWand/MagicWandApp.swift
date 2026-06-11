import SwiftUI

@main
struct MagicWandApp: App {
    /// Holds the list of previously-paired TVs and the active connection.
    @State private var tvStore = TVStore()
    @State private var connection = TVConnectionManager()

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environment(tvStore)
                .environment(connection)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
