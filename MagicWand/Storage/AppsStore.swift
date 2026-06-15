import Foundation
import Observation

/// Persists the user's "My Apps" list to local `UserDefaults`: which apps are shown,
/// their order, and pinned state. The first five entries are surfaced as the floating
/// quick-launch shortcuts, so reordering the list reorders the shortcuts too.
@MainActor
@Observable
final class AppsStore {
    private(set) var apps: [StreamingApp]

    private let defaults: UserDefaults
    private let key = "magicwand.myApps"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([StreamingApp].self, from: data),
           !decoded.isEmpty {
            self.apps = decoded
        } else {
            self.apps = StreamingApp.catalog
        }
    }

    /// The top five apps, exposed as the floating quick-launch shortcuts.
    var shortcuts: [StreamingApp] {
        Array(apps.prefix(5))
    }

    /// Catalog apps the user hasn't added yet (for the "add app" picker).
    var available: [StreamingApp] {
        let present = Set(apps.map(\.id))
        return StreamingApp.catalog.filter { !present.contains($0.id) }
    }

    // MARK: - Mutations

    func move(from source: IndexSet, to destination: Int) {
        apps.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func remove(at offsets: IndexSet) {
        apps.remove(atOffsets: offsets)
        persist()
    }

    func remove(_ app: StreamingApp) {
        apps.removeAll { $0.id == app.id }
        persist()
    }

    func add(_ app: StreamingApp) {
        guard !apps.contains(where: { $0.id == app.id }) else { return }
        apps.append(app)
        persist()
    }

    func togglePin(_ app: StreamingApp) {
        guard let index = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[index].isPinned.toggle()
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(apps) {
            defaults.set(data, forKey: key)
        }
    }
}
