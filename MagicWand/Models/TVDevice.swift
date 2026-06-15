import Foundation

/// A TV the user has discovered and/or paired with.
///
/// Persisted to `UserDefaults` (via `TVStore`) so the Library tab can list every
/// television the phone has connected to before. The `clientKey` returned by webOS
/// during pairing is stored here so we can silently re-connect without re-prompting
/// the user to re-enter a PIN on the TV.
struct TVDevice: Identifiable, Codable, Hashable {
    var id: UUID
    /// User-visible name, e.g. "LG TV UP7500PVG".
    var name: String
    /// Model string when known, e.g. "UP7500PVG".
    var modelName: String
    /// IP address / host on the local network, e.g. "192.168.1.42".
    var host: String
    /// webOS control port. Plain WebSocket is 3000, TLS is 3001.
    var port: Int
    /// Whether to connect over TLS (wss). UP-series webOS accepts plain ws on 3000.
    var useTLS: Bool
    /// The client-key handed back by the TV after a successful pairing.
    /// `nil` means we have discovered the TV but never paired with it.
    var clientKey: String?
    /// Last time we successfully connected, for sorting the Library.
    var lastConnected: Date?
    /// User-chosen nickname (the only editable field on the detail screen).
    var nickname: String?
    /// Device category, e.g. "webOS Smart TV".
    var deviceType: String?
    /// Screen size when known, e.g. "50\"".
    var screenSize: String?
    /// IP family, e.g. "IPv4".
    var ipType: String?

    init(
        id: UUID = UUID(),
        name: String,
        modelName: String = "",
        host: String,
        port: Int = 3000,
        useTLS: Bool = false,
        clientKey: String? = nil,
        lastConnected: Date? = nil,
        nickname: String? = nil,
        deviceType: String? = "webOS Smart TV",
        screenSize: String? = nil,
        ipType: String? = "IPv4"
    ) {
        self.id = id
        self.name = name
        self.modelName = modelName
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.clientKey = clientKey
        self.lastConnected = lastConnected
        self.nickname = nickname
        self.deviceType = deviceType
        self.screenSize = screenSize
        self.ipType = ipType
    }

    /// True once we have a stored client-key, i.e. the phone is already trusted by the TV.
    var isPaired: Bool { clientKey?.isEmpty == false }

    /// Preferred display label: nickname if set, otherwise the discovered name.
    var displayName: String {
        if let nickname, !nickname.trimmingCharacters(in: .whitespaces).isEmpty { return nickname }
        return name
    }

    /// The websocket URL used by the SSAP client.
    var socketURL: URL? {
        let scheme = useTLS ? "wss" : "ws"
        return URL(string: "\(scheme)://\(host):\(port)")
    }
}
