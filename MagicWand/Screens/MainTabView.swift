import SwiftUI

/// The three-tab interface that mirrors the reference app's bottom bar, with the
/// Settings tab replaced by a Library of previously-connected TVs.
struct MainTabView: View {
    enum Tab: Hashable {
        case casting, remote, library
    }

    @Environment(TVConnectionManager.self) private var connection
    @State private var selection: Tab = .remote

    var body: some View {
        TabView(selection: $selection) {
            CastingView()
                .tabItem { Label("Cast", systemImage: "airplayvideo") }
                .tag(Tab.casting)

            RemoteView()
                .tabItem { Label("Remote", systemImage: "av.remote.fill") }
                .tag(Tab.remote)

            LibraryView()
                .tabItem { Label("Library", systemImage: "rectangle.stack.fill") }
                .tag(Tab.library)
        }
        .tint(Theme.accent)
        // Floating quick-launch shortcut, above all tabs.
        .overlay(alignment: .bottomTrailing) {
            AppShortcutsButton()
        }
        .overlay(alignment: .top) {
            if let toast = connection.toast {
                ToastBanner(text: toast)
                    .task(id: toast) {
                        try? await Task.sleep(for: .seconds(4))
                        connection.clearToast()
                    }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: connection.toast)
    }
}
