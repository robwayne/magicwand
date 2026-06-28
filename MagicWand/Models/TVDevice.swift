import Foundation

/// A TV the user has discovered and/or paired with.
///
/// Persisted to `UserDefaults` (via `TVStore`) so the Library tab can list every
/// television the phone has connected to before. The pairing credential returned by the
/// TV (LG's client-key or Samsung's token) is stored here so we can silently re-connect
/// without re-prompting on the TV.
struct TVDevice: Identifiable, Codable, Hashable {
    var id: UUID
    /// Which make of TV; selects the control backend (LG/webOS, Samsung/Tizen, …).
    var vendor: TVVendor
    /// User-visible name, e.g. "LG TV UP7500PVG".
    var name: String
    /// Model string when known, e.g. "UP7500PVG".
    var modelName: String
    /// IP address / host on the local network, e.g. "192.168.1.42".
    var host: String
    /// Control port for the TV's remote protocol (vendor default unless set otherwise).
    var port: Int
    /// Whether to connect over TLS (wss). Vendor default unless explicitly set.
    var useTLS: Bool
    /// The pairing credential persisted after a successful pairing — for LG this is the
    /// webOS client-key, for Samsung it's the remote-control token.
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
    /// The TV's MAC address, captured while connected, used for Wake-on-LAN power-on.
    var macAddress: String?

    init(
        id: UUID = UUID(),
        vendor: TVVendor = .lg,
        name: String,
        modelName: String = "",
        host: String,
        port: Int? = nil,
        useTLS: Bool? = nil,
        clientKey: String? = nil,
        lastConnected: Date? = nil,
        nickname: String? = nil,
        deviceType: String? = nil,
        screenSize: String? = nil,
        ipType: String? = "IPv4",
        macAddress: String? = nil
    ) {
        self.id = id
        self.vendor = vendor
        self.name = name
        self.modelName = modelName
        self.host = host
        self.port = port ?? vendor.defaultPort
        self.useTLS = useTLS ?? vendor.defaultUsesTLS
        self.clientKey = clientKey
        self.lastConnected = lastConnected
        self.nickname = nickname
        self.deviceType = deviceType ?? Self.defaultDeviceType(for: vendor)
        self.screenSize = screenSize
        self.ipType = ipType
        self.macAddress = macAddress
    }

    // MARK: - Codable migration

    /// Older builds wrote out devices without a `vendor` field (all LG). Default to LG
    /// when decoding so previously-saved TVs keep working without re-pairing.
    private enum CodingKeys: String, CodingKey {
        case id, vendor, name, modelName, host, port, useTLS, clientKey
        case lastConnected, nickname, deviceType, screenSize, ipType, macAddress
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.vendor = (try? c.decode(TVVendor.self, forKey: .vendor)) ?? .lg
        self.name = try c.decode(String.self, forKey: .name)
        self.modelName = try c.decodeIfPresent(String.self, forKey: .modelName) ?? ""
        self.host = try c.decode(String.self, forKey: .host)
        self.port = (try? c.decode(Int.self, forKey: .port)) ?? self.vendor.defaultPort
        self.useTLS = (try? c.decode(Bool.self, forKey: .useTLS)) ?? self.vendor.defaultUsesTLS
        self.clientKey = try c.decodeIfPresent(String.self, forKey: .clientKey)
        self.lastConnected = try c.decodeIfPresent(Date.self, forKey: .lastConnected)
        self.nickname = try c.decodeIfPresent(String.self, forKey: .nickname)
        self.deviceType = try c.decodeIfPresent(String.self, forKey: .deviceType)
            ?? Self.defaultDeviceType(for: self.vendor)
        self.screenSize = try c.decodeIfPresent(String.self, forKey: .screenSize)
        self.ipType = try c.decodeIfPresent(String.self, forKey: .ipType) ?? "IPv4"
        self.macAddress = try c.decodeIfPresent(String.self, forKey: .macAddress)
    }

    private static func defaultDeviceType(for vendor: TVVendor) -> String {
        switch vendor {
        case .lg: "webOS Smart TV"
        case .samsung: "Tizen Smart TV"
        case .generic: "Smart TV"
        }
    }

    // MARK: - Derived

    /// True once we have a stored credential (client-key/token).
    var isPaired: Bool { clientKey?.isEmpty == false }

    /// Preferred display label: nickname if set, otherwise the discovered name.
    var displayName: String {
        if let nickname, !nickname.trimmingCharacters(in: .whitespaces).isEmpty { return nickname }
        return name
    }

    /// The WebSocket URL used by the active control backend.
    var socketURL: URL? {
        let scheme = useTLS ? "wss" : "ws"
        return URL(string: "\(scheme)://\(host):\(port)")
    }
}
