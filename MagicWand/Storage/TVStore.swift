import Foundation
import Observation

/// Persists the list of TVs the phone has connected to, in local `UserDefaults`.
///
/// Kept intentionally simple per the project brief: a single Codable array encoded
/// to JSON under one key. This is the source of truth for the Library tab.
@MainActor
@Observable
final class TVStore {
    private(set) var devices: [TVDevice] = []

    /// The id of the most-recently-selected TV, so the app reopens on it.
    var lastSelectedID: UUID? {
        didSet { defaults.set(lastSelectedID?.uuidString, forKey: Keys.lastSelected) }
    }

    private let defaults: UserDefaults
    private enum Keys {
        static let devices = "magicwand.savedTVs"
        static let lastSelected = "magicwand.lastSelectedTV"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: - Loading / saving

    private func load() {
        if let raw = defaults.string(forKey: Keys.lastSelected) {
            lastSelectedID = UUID(uuidString: raw)
        }
        guard let data = defaults.data(forKey: Keys.devices) else { return }
        if let decoded = try? JSONDecoder().decode([TVDevice].self, from: data) {
            devices = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(devices) {
            defaults.set(data, forKey: Keys.devices)
        }
    }

    // MARK: - Mutations

    /// Insert a freshly-discovered or freshly-paired TV, or update one we already know
    /// (matched by host) so we never create duplicates and always keep the newest key.
    @discardableResult
    func upsert(_ device: TVDevice) -> TVDevice {
        if let index = devices.firstIndex(where: { $0.host == device.host }) {
            var existing = devices[index]
            existing.name = device.name.isEmpty ? existing.name : device.name
            existing.modelName = device.modelName.isEmpty ? existing.modelName : device.modelName
            // Only overwrite vendor/port/TLS when the incoming value is meaningful, so a
            // discovery update never accidentally downgrades a known-Samsung TV to LG.
            if device.vendor != .generic { existing.vendor = device.vendor }
            existing.port = device.port
            existing.useTLS = device.useTLS
            if let key = device.clientKey, !key.isEmpty {
                existing.clientKey = key
            }
            if let date = device.lastConnected {
                existing.lastConnected = date
            }
            // Preserve user edits (nickname) and fill in any newly-known metadata.
            if let nickname = device.nickname { existing.nickname = nickname }
            if let type = device.deviceType, !type.isEmpty { existing.deviceType = type }
            if let size = device.screenSize, !size.isEmpty { existing.screenSize = size }
            if let ipType = device.ipType, !ipType.isEmpty { existing.ipType = ipType }
            if let mac = device.macAddress, !mac.isEmpty { existing.macAddress = mac }
            devices[index] = existing
            persist()
            return existing
        } else {
            devices.append(device)
            persist()
            return device
        }
    }

    /// Record that we just connected to a TV (updates the timestamp + stored key).
    func markConnected(_ device: TVDevice, clientKey: String?) {
        var updated = device
        updated.lastConnected = Date()
        if let key = clientKey, !key.isEmpty { updated.clientKey = key }
        let saved = upsert(updated)
        lastSelectedID = saved.id
    }

    /// Replace a stored device by id (used when editing the nickname on the detail screen).
    func update(_ device: TVDevice) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[index] = device
        persist()
    }

    func remove(_ device: TVDevice) {
        devices.removeAll { $0.id == device.id }
        if lastSelectedID == device.id { lastSelectedID = nil }
        persist()
    }

    func device(withID id: UUID?) -> TVDevice? {
        guard let id else { return nil }
        return devices.first { $0.id == id }
    }

    /// TVs sorted for the Library: most recently connected first, then unpaired.
    var sortedForLibrary: [TVDevice] {
        devices.sorted {
            ($0.lastConnected ?? .distantPast) > ($1.lastConnected ?? .distantPast)
        }
    }
}
