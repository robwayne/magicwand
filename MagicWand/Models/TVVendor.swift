import Foundation

/// The make of a TV, which determines which control backend the app uses.
///
/// New vendors are added here; each one ships its own `TVControlBackend` implementation
/// (LG → `LGWebOSBackend`, Samsung → `TizenBackend`). `generic` is reserved for a future
/// HTTP-only path (e.g. Roku ECP) and currently has no backend.
enum TVVendor: String, Codable, CaseIterable, Hashable {
    case lg
    case samsung
    case generic

    var displayName: String {
        switch self {
        case .lg: "LG (webOS)"
        case .samsung: "Samsung (Tizen)"
        case .generic: "Smart TV"
        }
    }

    /// Default control port for this vendor's primary remote protocol.
    var defaultPort: Int {
        switch self {
        case .lg: 3000        // webOS SSAP, plain WebSocket
        case .samsung: 8002   // Tizen samsung.remote.control, WSS
        case .generic: 0
        }
    }

    var defaultUsesTLS: Bool {
        switch self {
        case .lg: false
        case .samsung: true
        case .generic: false
        }
    }
}
